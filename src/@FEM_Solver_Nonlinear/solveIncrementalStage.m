function success = solveIncrementalStage(obj, Stage, strategy, s)
% SOLVEINCREMENTALSTAGE  Strategy-driven arc-length stage driver.
%
% Replaces solveArcLengthStage by delegating predictor/constraint logic
% to the IncrementalStrategy object. Uses while-loop termination (A3)
% instead of fixed step count.
%
% Inputs:
%   Stage    - LoadingStage object
%   strategy - IncrementalStrategy subclass (RiksStrategy, etc.)
%   s        - Stage index (for logging)

% ------------------------------------------------------------------
% 0. Stage parameters
% ------------------------------------------------------------------
opts  = obj.Options;
tol   = opts.Tolerance;
maxit = opts.MaxIterations;
max_trials = 5;

% Initialize monitor
mon = ConvergenceMonitor();
mon.Tolerance = tol;
mon.MaxIterations = maxit;
mon.NormType = opts.NormType;

% ------------------------------------------------------------------
% 1. External load vector for this stage
% ------------------------------------------------------------------
F_ext_total = obj.calculateGlobalTargetForce(Stage.ActiveLoads);

% ------------------------------------------------------------------
% 2. Displacement BCs and free-DOF partition
% ------------------------------------------------------------------
[fixed_dofs, disp_targets] = getDispload(obj, Stage.ActiveBCs);
nDofs     = length(obj.U);
free_dofs = setdiff(1:nDofs, fixed_dofs)';

% Apply prescribed displacements once at stage start
U_stage_start              = obj.U;
U_stage_start(fixed_dofs)  = disp_targets;

% ------------------------------------------------------------------
% 3. Assembly closure
% ------------------------------------------------------------------
    function [R, KT, fext, TH] = assembleForArcLength(u_in, lambda_in)
        [KT_full, F_int_loc, TH] = obj.assembleTangentSystem(u_in);
        fext = F_ext_total;
        R    = F_int_loc - lambda_in * fext;
        R(fixed_dofs) = 0;
        KT   = KT_full;
    end

% ------------------------------------------------------------------
% 4. Initialise state
% ------------------------------------------------------------------
if isempty(obj.LambdaHist)
    lambda = 0;
else
    lambda = obj.LambdaHist(end);
end

u_converged = U_stage_start;
dup_prev    = zeros(nDofs, 1);
stage_step  = 0;

% While-loop termination (A3 fix)
accumulated = 0;
maxSteps = max(1, ceil(10 * Stage.Duration / strategy.ArcLengthMin));

fprintf('    strategy=%s  radius=%.2e [%.2e,%.2e]  λ₀=%.4f\n', ...
    class(strategy), strategy.ArcLengthRadius, ...
    strategy.ArcLengthMin, strategy.ArcLengthMax, lambda);

% ------------------------------------------------------------------
% 5. Main stepping loop
% ------------------------------------------------------------------
success = false;

stepCount = 0;
while accumulated < Stage.Duration && stepCount < maxSteps
    stepCount = stepCount + 1;

    u0_step      = u_converged;
    lambda0_step = lambda;

    % --- Reset L-BFGS history for new increment ---
    obj.lbfgs_S = {};
    obj.lbfgs_Y = {};

    % --- Adaptive trial loop ---
    trial_ds   = strategy.ArcLengthRadius;
    converged  = false;
    iters_used = 0;
    F_int_conv = zeros(nDofs, 1);

    for trial = 1:max_trials
        fprintf('   step %d  trial %d  ds=%.3e  λ=%.4f ... ', ...
            stepCount, trial, trial_ds, lambda0_step);

        % ---- Predictor ----
        [~, KT_pred, fext_pred, ~] = assembleForArcLength(u0_step, lambda0_step);
        KT_ff = KT_pred(free_dofs, free_dofs);

        if rcond(full(KT_ff)) < 1e-13
            fprintf('SINGULAR\n');
            converged = false;
            break;
        end

        [u_pred, l_pred, dup_step, dlp] = strategy.predictor( ...
            KT_ff, fext_pred(free_dofs), u0_step, lambda0_step, ...
            dup_prev, trial_ds, free_dofs, nDofs);

        % ---- Corrector loop (GMNIA v4 unified loop) ----
        u_trial        = u_pred;
        lambda_trial   = l_pred;
        mon.reset(fext_pred(free_dofs), opts);
        
        rebuild_tangent = true;
        L_KT            = [];
        
        for i = 1:maxit
            iters_used = i;

            % 1. Evaluation at current trial state
            [g, h_raw, s_val] = strategy.constraint( ...
                u_trial(free_dofs), lambda_trial, ...
                u0_step(free_dofs), lambda0_step, ...
                dup_step(free_dofs), dlp, trial_ds);

            if rebuild_tangent
                [R, KT, fext_curr, TrialHist_trial] = assembleForArcLength(u_trial, lambda_trial);
                KT_ff = KT(free_dofs, free_dofs);
                L_KT  = decomposition(KT_ff, 'auto');
                rebuild_tangent = false;
            else
                % Cheap residual update (only F_int)
                F_int_loc = obj.assembleinternalforceONLY(u_trial);
                R = F_int_loc - lambda_trial * F_ext_total;
                R(fixed_dofs) = 0;
            end
            
            R_f    = R(free_dofs);
            fext_f = F_ext_total(free_dofs);
            F_int_conv = R + lambda_trial * F_ext_total;

            if mon.check(R_f, [], u_trial(free_dofs), fext_f, i)
                converged = true;
                F_int_conv = R + lambda_trial * F_ext_total;
                break;
            end
            
            % Check recommendations
            action = mon.recommend();
            if strcmp(action, 'abort')
                fprintf('DIVERGED '); break;
            elseif strcmp(action, 'cutback')
                fprintf('STAGNATED '); break;
            end

            % 2. Solve for directions (Hybrid Newton / L-BFGS)
            use_quasi = opts.UseLBFGS && i > 1 && ~isempty(obj.lbfgs_S);
            accept_lbfgs = false;
            
            if use_quasi
                [p_I,  acc_I]  = obj.lbfgsDirection(obj.lbfgs_S, obj.lbfgs_Y, -fext_f);
                [p_II, acc_II] = obj.lbfgsDirection(obj.lbfgs_S, obj.lbfgs_Y, R_f);
                if acc_I && acc_II
                    du_I_f = -p_I; du_II_f = -p_II;
                    accept_lbfgs = true;
                end
            end
            
            if ~accept_lbfgs
                % Fallback: True Newton or Factorized Tangent
                if i > 7 % Rebuild every 7 iters regardless of L-BFGS
                    rebuild_tangent = true; continue; 
                end
                du_I_f  =  L_KT \ fext_f;
                du_II_f = -(L_KT \ R_f);
            end

            % 3. Update increment
            h_f = zeros(length(free_dofs), 1);
            if ~isempty(h_raw), h_f = h_raw; end

            denom = s_val + h_f' * du_I_f;
            if abs(denom) < 1e-14 * (abs(s_val) + 1)
                converged = false; break;
            end

            dl = -(g + h_f' * du_II_f) / denom;
            du_f = dl * du_I_f + du_II_f;

            % 4. Line Search if requested or oscillating
            eta = 1.0;
            if strcmp(action, 'linesearch') || opts.UseLineSearch
                if strcmp(opts.LineSearchMethod, 'armijo')
                    eta = obj.armijoSearch(u_trial, du_f, R, F_ext_total, free_dofs);
                else
                    eta = obj.linesearch(u_trial, du_f, R, F_ext_total, free_dofs);
                end
            end
            
            % 5. Apply update and store L-BFGS history
            du_eff_f = eta * du_f;
            u_trial_next        = u_trial;
            u_trial_next(free_dofs) = u_trial(free_dofs) + du_eff_f;
            lambda_trial_next   = lambda_trial + dl;
            
            if opts.UseLBFGS
                % Calculate residual increment for Y list
                F_int_next = obj.assembleinternalforceONLY(u_trial_next);
                R_next = F_int_next - lambda_trial_next * F_ext_total;
                y_i = R_next(free_dofs) - R_f;
                
                % Store pair
                obj.lbfgs_S{end+1} = du_eff_f;
                obj.lbfgs_Y{end+1} = y_i;
                if numel(obj.lbfgs_S) > opts.LBFGSHistory
                    obj.lbfgs_S(1) = []; obj.lbfgs_Y(1) = [];
                end
            end
            
            u_trial      = u_trial_next;
            lambda_trial = lambda_trial_next;
        end

        if converged
            fprintf('OK (%d iters)\n', iters_used);
            break;
        else
            fprintf('FAIL\n');
            if trial < max_trials
                trial_ds = max(trial_ds * 0.5, strategy.ArcLengthMin);
                fprintf('         -> halving radius to %.3e\n', trial_ds);
            end
        end
    end

    if ~converged
        fprintf('!!! Stage %d step %d: failed after %d trials.\n', s, stepCount, max_trials);
        success = false;
        return;
    end

    % --- Accept converged state ---
    obj.commitHistory(TrialHist_trial);
    dup_prev    = u_trial - u0_step;
    u_converged = u_trial;
    lambda      = lambda_trial;
    stage_step  = stage_step + 1;

    % Accumulate progress
    accumulated = accumulated + trial_ds;

    % Check TargetLambda
    if isprop(Stage, 'TargetLambda') && lambda >= Stage.TargetLambda
        fprintf('    TargetLambda %.4f reached.\n', Stage.TargetLambda);
        break;
    end

    % --- Adaptive radius for next step ---
    strategy.adaptRadius(iters_used, maxit);

    % --- Commit to object state ---
    obj.U = u_converged;

    % Archive to SolutionState (Primary history store)
    reaction_struct = [];
    if ~isempty(F_int_conv)
        reaction_struct = struct('dofs', fixed_dofs, 'values', F_int_conv(fixed_dofs));
    end
    
    plasticSnap = [];
    if obj.hasMaterialPlastic()
        plasticSnap = cell(size(obj.Elements));
        for e = 1:length(obj.Elements)
            sctr = obj.SctrMap(e, :);
            u_el = u_converged(sctr);
            obj.Elements{e}.recoverGaussPointData(u_el);
            plasticSnap{e} = obj.Elements{e}.HistoryData;
        end
    end
    
    % This handles U_Hist, LambdaHist, ArcLengthHist, and Reaction data internally
    obj.state.appendStep(u_converged, lambda, plasticSnap, reaction_struct, trial_ds);

    % Event notification
    evtData = SolverEventData(obj.Time + accumulated, ...
        obj.StepCount, u_converged, lambda, iters_used);
    notify(obj, 'StepConverged', evtData);
end

% ------------------------------------------------------------------
% 6. Finalize Stage
% ------------------------------------------------------------------
obj.Time = obj.Time + Stage.Duration;
if isprop(obj, 'F_ext_start')
    obj.F_ext_start = F_ext_total;
end

success = true;
fprintf('    Stage %d: %d steps converged.  λ_final = %.4f\n', s, stage_step, lambda);
end

% ------------------------------------------------------------------
% LOCAL HELPERS
% ------------------------------------------------------------------
function [R, KT, fext_curr, TrialHist] = assembleForArcLength(obj, u_trial, lambda_trial)
    % ASSEMBLEFORARCLENGTH - Helper for unified residual/tangent evaluation
    F_ext_total = obj.F_ext_start + (obj.Model.GlobalF - obj.F_ext_start);
    [KT, F_int, TrialHist] = obj.assembleTangentSystem(u_trial);
    fext_curr = lambda_trial * F_ext_total;
    R = F_int - fext_curr;
end
