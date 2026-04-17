function success = solveIncrementalStage(obj, Stage, strategy, stageIdx)
% SOLVEINCREMENTALSTAGE  Strategy-driven arc-length stage driver.
%
% Replaces solveArcLengthStage by delegating predictor/constraint logic
% to the IncrementalStrategy object. Uses while-loop termination (A3)
% instead of fixed step count.
%
% Inputs:
%   Stage    - LoadingStage object
%   strategy - IncrementalStrategy subclass (RiksStrategy, etc.)
%   stageIdx - Stage index (for logging)

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
        nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
        [KT_full, F_int_loc, TH] = Assembler.tangent(u_in, obj.Elements, obj.SctrMap, nDofs);
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

        % Initialize trial state and call pure corrector
        u_trial = u_pred;
        lambda_trial = l_pred;
        
        [u_trial, lambda_trial, F_int_trial, TrialHist_trial, converged, iters_used] = ...
            obj.correctorLoop(u0_step, lambda0_step, strategy, trial_ds, ...
            @assembleForArcLength, free_dofs, fixed_dofs, u_pred, l_pred, ...
            dup_step, dlp, F_ext_total, mon, opts);
        
        % Extract final internal force for reaction computation
        F_int_conv = F_int_trial;

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
        fprintf('!!! Stage %d step %d: failed after %d trials.\n', stageIdx, stepCount, max_trials);
        success = false;
        return;
    end

    % --- Accept converged state to persistent storage ---
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

    % Commit step with side effects (History, Archive, Notify)
    obj.acceptStep(u_converged, lambda, iters_used, TrialHist_trial, ...
        F_int_conv, fixed_dofs, Stage, stageIdx, accumulated, trial_ds);
end

% ------------------------------------------------------------------
% 6. Finalize Stage
% ------------------------------------------------------------------
obj.Time = obj.Time + Stage.Duration;
if isprop(obj, 'F_ext_start')
    obj.F_ext_start = F_ext_total;
end

success = true;
fprintf('    Stage %d: %d steps converged.  λ_final = %.4f\n', stageIdx, stage_step, lambda);
end
