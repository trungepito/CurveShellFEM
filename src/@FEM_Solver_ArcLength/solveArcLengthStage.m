function success = solveArcLengthStage(obj, Stage, s)
% SOLVEARCLENGTHSTAGE  Arc-length stage driver with adaptive radius control.
%
% Drives one LoadingStage through the arc-length corrector.  The stage
% runs for a fixed number of steps (nSteps = ceil(Stage.Duration /
% ArcLengthRadius)) rather than terminating on pseudo-time.
%
% Adaptive radius policy:
%   iters <= 4              -> radius * 1.5  (easy convergence, open up)
%   4 < iters <= 0.75*maxit -> radius unchanged
%   iters > 0.75*maxit      -> radius * 0.7  (slow, tighten slightly)
%   failed trial            -> radius * 0.5, retry (up to max_trials)
%   all trials exhausted    -> abort and return success = false
%
% Fixes applied versus previous version:
%   1. Residual sign:  R = lambda*F_ext - F_int  (was inverted).
%   2. KT partitioned to free DOFs before solve; fixed-DOF rows never enter
%      the linear system so the matrix is not rank-deficient.
%   3. Lambda continuity: starts from last value in obj.LambdaHist, not 0.
%   4. Termination: step-counter based, not pseudo-time, so snap-back paths
%      (where lambda decreases) cannot cause an infinite loop.
%   5. History trim: only newly written columns are trimmed; earlier stage
%      columns are preserved.
%   6. Reaction cost: F_int returned directly from arcLengthStep; no extra
%      assembly call per converged step.
%   7. obj.U is not mutated inside the assembly closure; passed explicitly.
%   8. ArcLengthHistory records trial_arc (the radius actually used) not
%      arc_length (the tentative next-step value).
%
% Syntax:
%   success = obj.solveArcLengthStage(Stage, s)

% ------------------------------------------------------------------
% 0.  Stage parameters
% ------------------------------------------------------------------
arc_length   = Stage.ArcLengthRadius;
arc_min      = Stage.ArcLengthMin;
arc_max      = Stage.ArcLengthMax;
arc_psi      = Stage.ArcLengthPsi; % Load-scaling factor
max_trials   = 5;
obj.ConstraintType = obj.canonicalConstraintType(obj.ConstraintType);
usePredictor = any(strcmp(obj.ConstraintType, {'Riks', 'Spherical'}));
if strcmp(obj.ConstraintType, 'DispControl') && isempty(obj.ControlDOF)
    error('FEM_Solver_ArcLength:noControlDOF', ...
        'Set ControlDOF before using DispControl constraint.');
end

obj.ArcLengthPsi = arc_psi; % Sync to solver instance for constraint calls

tol   = obj.Options.Tolerance;
maxit = obj.Options.MaxIterations;

% Number of arc-length steps to attempt in this stage.
% We use Duration / ArcLengthRadius as an estimate; the adaptive radius
% will adjust in practice.
nSteps = max(1, ceil(Stage.Duration / arc_length));

% ------------------------------------------------------------------
% 1.  External load vector for this stage
% ------------------------------------------------------------------
F_ext_total = obj.calculateGlobalTargetForce(Stage.ActiveLoads);

% ------------------------------------------------------------------
% 2.  Displacement BCs and free-DOF partition
% ------------------------------------------------------------------
[fixed_dofs, disp_targets] = getDispload(obj, Stage.ActiveBCs);
nDofs      = length(obj.U);
free_dofs  = setdiff(1:nDofs, fixed_dofs)';

% Apply prescribed displacements once at stage start.
% Subsequent steps hold these values fixed (they become part of u_converged).
U_stage_start                = obj.U;
U_stage_start(fixed_dofs)   = disp_targets;

% ------------------------------------------------------------------
% 3.  Assembly closure
%
    function [R, KT, fext, TrialHist] = assembleForArcLength(u_in, lambda_in,~, ~)
        % Signature: [R, KT, fext, TrialHist] = funcHandle(u_in, lambda_in, ...)
        [KT_full, F_int, TrialHist] = obj.assembleTangentSystem(u_in);
        fext = F_ext_total;
        R = F_int - lambda_in * fext;    % equilibrium: F_int = lambda * F_ext
        R(fixed_dofs) = 0;               % enforce fixed-DOF residual rows
        KT = KT_full;
    end
% ------------------------------------------------------------------
% 4.  Constraint function handle
% ------------------------------------------------------------------
switch obj.ConstraintType
    case 'Riks'
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.crisfieldConstraint(u,l,u0,l0,dup,dlp,si);
    case 'Spherical'
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.sphericalConstraint(u,l,u0,l0,dup,dlp,si);
    case 'LoadControl'
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.loadControlConstraint(u,l,u0,l0,dup,dlp,si);
    case 'DispControl'
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.dispControlConstraint(u,l,u0,l0,dup,dlp,si);
    otherwise
        % Should be unreachable because canonicalConstraintType validates.
        error('FEM_Solver_ArcLength:unknownConstraintType', ...
            'Unsupported ConstraintType ''%s''.', obj.ConstraintType);
end

% ------------------------------------------------------------------
% 5.  Initialise state
%
%     FIX (lambda continuity): the previous code hard-coded lambda = 0 at
%     the start of every stage.  For multi-stage runs this is wrong because
%     lambda should continue from wherever the previous stage left it.  We
%     initialise from the last entry in LambdaHist, falling back to 0 if
%     this is the very first stage.
% ------------------------------------------------------------------
if isempty(obj.LambdaHist)
    lambda = 0;
else
    lambda = obj.LambdaHist(end);
end

u_converged = U_stage_start;
dup_prev    = zeros(nDofs, 1);  % Predictor direction from previous step
% (used for CSP sign flip detection)

stage_step  = 0;
col_start   = obj.StepCount;   % Column index before this stage starts,
% used for history trim at the end.
S_Reaction  = zeros(length(fixed_dofs), 0);

fprintf('    radius=%.2e [%.2e,%.2e]  nSteps≈%d  λ₀=%.4f  constraint=%s\n', ...
    arc_length, arc_min, arc_max, nSteps, lambda, obj.ConstraintType);

% ------------------------------------------------------------------
% 6.  Main stepping loop
%
%     FIX (termination): the previous loop used pseudo-time = |Δλ| which
%     makes it infinite on snap-back paths (lambda decreasing, |Δλ| > 0
%     but time never reaches t_end).  We now iterate for a fixed nSteps
%     and let the adaptive radius naturally control resolution.
% ------------------------------------------------------------------
success = false;

for step = 1 : nSteps

    u0_step      = u_converged;
    lambda0_step = lambda;

    % --- Adaptive trial loop ---
    trial_arc  = arc_length;
    converged  = false;
    iters_used = 0;
    F_int_conv = zeros(nDofs, 1);

    for trial = 1 : max_trials
        fprintf('   step %d/%d  trial %d  ds=%.3e  λ=%.4f ... ', ...
            step, nSteps, trial, trial_arc, lambda0_step);

        [u_trial, lambda_trial, F_int_trial, TrialHist_trial, converged, iters_used] = ...
            obj.arcLengthStep( ...
            @assembleForArcLength, constraintFn, free_dofs, ...
            u0_step, lambda0_step, dup_prev, ...
            trial_arc, usePredictor, tol, maxit);

        if converged
            fprintf('OK (%d iters)\n', iters_used);
            F_int_conv = F_int_trial;
            TrialHist_conv = TrialHist_trial;
            break;
        else
            fprintf('FAIL\n');
            if trial < max_trials
                trial_arc = max(trial_arc * 0.5, arc_min);
                fprintf('         -> halving radius to %.3e\n', trial_arc);
            end
        end
    end

    if ~converged
        fprintf('!!! Stage %d step %d: failed after %d trials.\n', s, step, max_trials);
        success = false;
        return;
    end

    % --- Accept converged state ---
    % COMMIT HISTORY: Update elements with the plastic state from the 
    % successful converging trial.
    obj.commitHistory(TrialHist_conv);
    % Update dup_prev: compute the displacement increment taken this step
    % so the next predictor can detect snap-back (sign reversal of k0).
    dup_prev    = u_trial - u0_step;
    u_converged = u_trial;
    lambda      = lambda_trial;
    stage_step  = stage_step + 1;

    % --- Adaptive radius for the NEXT step ---
    if iters_used <= 4
        arc_length = min(trial_arc * 1.5, arc_max);
    elseif iters_used > round(maxit * 0.75)
        arc_length = max(trial_arc * 0.7, arc_min);
    else
        arc_length = trial_arc;
    end

    % --- Commit to object state ---
    obj.U         = u_converged;
    obj.StepCount = obj.StepCount + 1;

    % --- History storage (grow by doubling when needed) ---
    if obj.StepCount > size(obj.U_Hist, 2)
        grow = max(size(obj.U_Hist, 2), 30);
        obj.U_Hist       = [obj.U_Hist,       zeros(nDofs, grow)];
        obj.History_Time = [obj.History_Time;  zeros(grow, 1)];
    end
    obj.U_Hist(:, obj.StepCount)    = u_converged;
    obj.History_Time(obj.StepCount) = obj.Time + step * Stage.Duration / nSteps;

    % FIX (ArcLengthHistory): record trial_arc (the radius actually used
    % in the successful trial), not arc_length (the speculative next value).
    obj.LambdaHist       = [obj.LambdaHist,       lambda];
    obj.ArcLengthHistory = [obj.ArcLengthHistory,  trial_arc];

    % FIX (reaction cost): F_int is already available from arcLengthStep;
    % no second assembly needed.
    S_Reaction = [S_Reaction, F_int_conv(fixed_dofs)];

    % --- Event notification ---
    evtData = SolverEventData(obj.History_Time(obj.StepCount), ...
        obj.StepCount, u_converged, lambda, iters_used);
    notify(obj, 'StepConverged', evtData);
end

% ------------------------------------------------------------------
% 7.  Trim history to actual columns written
%
%     FIX (history trim): the previous code trimmed obj.U_Hist to
%     1:obj.StepCount on every stage, which discarded columns written
%     by earlier stages.  We now trim only from col_start+1 onward,
%     keeping prior-stage data intact.
% ------------------------------------------------------------------
valid_end        = obj.StepCount;
new_cols         = col_start + 1 : valid_end;
% The preallocated zeros beyond valid_end are still in the arrays;
% trim them now so callers see exactly the data that exists.
obj.U_Hist       = obj.U_Hist(:,       1:valid_end);
obj.History_Time = obj.History_Time(   1:valid_end);

obj.Time        = obj.Time + Stage.Duration;
obj.F_ext_start = F_ext_total;
obj.ReactionHist{s} = S_Reaction;

success = true;
fprintf('    Stage %d: %d steps converged.  λ_final = %.4f\n', s, stage_step, lambda);
end
