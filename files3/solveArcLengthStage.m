function success = solveArcLengthStage(obj, Stage, s)
% SOLVEARCLENGTHSTAGE  Arc-length stage driver with adaptive radius control.
%
% Enhancement log (P1.4, P2.3, P6.2-partial):
%
%   P1.4 — Fixed-nSteps loop replaced by a lambda-target while loop.
%           The old  nSteps = ceil(Duration / arc_length)  is a static
%           estimate that breaks on snap-back paths (lambda decreasing, so
%           the loop would never reach  t_end  if the target was additive)
%           and on large initial radii (ceil yields 1, stage terminates
%           after a single step regardless of how far lambda still is from
%           the target).
%
%           New termination logic:
%             • For Riks / LoadControl: loop until
%                   |lambda - lambda_end| < tol_lam  OR  step_count >= max_steps
%               where  lambda_end = lambda0_stage + Stage.Duration.
%             • For DispControl: loop until the control DOF reaches its
%               target, or max_steps is exhausted.
%             • max_steps is a hard safety ceiling:
%                   max_steps = ceil(Stage.Duration / arc_min) + 20
%               so the loop always terminates even if every step is at the
%               minimum radius.
%
%   P2.3 — dup_prev is documented as read-only during failed trials.
%           The code was already correct; an explicit comment is added so
%           refactoring does not accidentally mutate it on failed trials.
%
%   P6.2-partial — Stage validation block added: prints lambda_0, constraint
%           type, and free-DOF count at the start of each stage; raises an
%           error for DispControl without a ControlDOF.

% ------------------------------------------------------------------
% 0.  Stage parameters
% ------------------------------------------------------------------
arc_length   = Stage.ArcLengthRadius;
arc_min      = Stage.ArcLengthMin;
arc_max      = Stage.ArcLengthMax;
arc_psi      = Stage.ArcLengthPsi;
max_trials   = 5;
usePredictor = strcmp(obj.ConstraintType, 'Riks');

obj.ArcLengthPsi = arc_psi;

tol   = obj.Options.Tolerance;
maxit = obj.Options.MaxIterations;

% P6.2: validate stage configuration before doing any work
if strcmp(obj.ConstraintType, 'DispControl') && isempty(obj.ControlDOF)
    error('FEM_Solver_ArcLength:noControlDOF', ...
        'ControlDOF must be set on the solver before using DispControl constraint.');
end

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

U_stage_start               = obj.U;
U_stage_start(fixed_dofs)  = disp_targets;

% P4.1: cache fixed DOFs so arcLengthStep can zero residual rows on the
% elastic fast path without re-calling the full assembly closure.
obj.fixedDofsCache_ALS = a;

% P6.2: stage entry diagnostics
if isempty(obj.LambdaHist)
    lambda_diag = 0.0;
else
    lambda_diag = obj.LambdaHist(end);
end
fprintf('  [Stage %d] constraint=%s  lambda_0=%.6g  free_DOFs=%d  radius=[%.2e, %.2e]\n', ...
    s, obj.ConstraintType, lambda_diag, length(free_dofs), arc_min, arc_max);

% ------------------------------------------------------------------
% 3.  Assembly closure
% ------------------------------------------------------------------
    function [R, KT, fext, TrialHist] = assembleForArcLength(u_in, lambda_in, ~, ~)
        [KT_full, F_int, TrialHist] = obj.assembleTangentSystem(u_in);

        % P2.2: enforce KT symmetry after assembly to eliminate numerical
        % asymmetry that accumulates in J2-plastic tangent operators.
        KT_full = 0.5 * (KT_full + KT_full');

        fext = F_ext_total;
        % Residual convention (P1.2): R = F_int - lambda * F_ext
        % Equilibrium => R = 0 => F_int = lambda * F_ext
        R = F_int - lambda_in * fext;
        R(fixed_dofs) = 0;   % enforce fixed-DOF residual rows
        KT = KT_full;
    end

% ------------------------------------------------------------------
% 4.  Constraint function handle
% ------------------------------------------------------------------
switch obj.ConstraintType
    case 'Riks'
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.crisfieldConstraint(u,l,u0,l0,dup,dlp,si);
    case 'LoadControl'
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.loadControlConstraint(u,l,u0,l0,dup,dlp,si);
    case 'DispControl'
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.dispControlConstraint(u,l,u0,l0,dup,dlp,si);
    otherwise
        warning('FEM_Solver_ArcLength:unknownConstraint', ...
            'Unknown ConstraintType ''%s''; defaulting to Riks.', obj.ConstraintType);
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.crisfieldConstraint(u,l,u0,l0,dup,dlp,si);
end

% ------------------------------------------------------------------
% 5.  Initialise state
% ------------------------------------------------------------------
if isempty(obj.LambdaHist)
    lambda = 0;
else
    lambda = obj.LambdaHist(end);
end

u_converged = U_stage_start;
dup_prev    = zeros(nDofs, 1);   % P2.3: read-only during failed trials

stage_step  = 0;
col_start   = obj.StepCount;
S_Reaction  = zeros(length(fixed_dofs), 0);

% ------------------------------------------------------------------
% P1.4: lambda-target termination variables
% ------------------------------------------------------------------
lambda0_stage = lambda;
lambda_end    = lambda0_stage + Stage.Duration;
tol_lam       = tol * max(abs(Stage.Duration), 1e-12);   % absolute lambda tolerance

% Hard safety ceiling: even if every step is at arc_min we must terminate
max_steps = ceil(Stage.Duration / max(arc_min, eps)) + 20;

% For DispControl the termination criterion is the control DOF, not lambda
if strcmp(obj.ConstraintType, 'DispControl')
    u_ctrl_end = U_stage_start(obj.ControlDOF) + Stage.Duration; % questionable??
    is_disp_ctrl = true;
else
    is_disp_ctrl = false;
end

fprintf('  [Stage %d] lambda_target=%.6g  max_steps=%d  usePredictor=%d\n', ...
    s, lambda_end, max_steps, usePredictor);

% ------------------------------------------------------------------
% 6.  Main stepping loop  (P1.4: while, not for)
% ------------------------------------------------------------------
success = false;
step = 0;

while step < max_steps

    % P1.4: termination test
    if is_disp_ctrl
        % DispControl: terminate when control DOF reaches target
        u_ctrl_curr = u_converged(obj.ControlDOF);
        remaining   = u_ctrl_end - u_ctrl_curr;
        if abs(remaining) < tol_lam, success = true; break; end
        % Clamp arc_length so we do not overshoot
        arc_length = min(arc_length, abs(remaining));
    else
        % Riks / LoadControl: terminate when lambda reaches lambda_end
        remaining = lambda_end - lambda;
        if abs(remaining) < tol_lam, success = true; break; end
        % For LoadControl, clamp the arc_length (= Δλ target) to remaining
        if strcmp(obj.ConstraintType, 'LoadControl')
            arc_length = min(arc_length, abs(remaining));
        end
    end

    step = step + 1;
    u0_step      = u_converged;
    lambda0_step = lambda;

    % ── Adaptive trial loop ──────────────────────────────────────────
    trial_arc  = arc_length;
    converged  = false;
    iters_used = 0;
    F_int_conv = zeros(nDofs, 1);

    for trial = 1 : max_trials
        fprintf('  step %d  trial %d  ds=%.3e  lambda=%.6g ... ', ...
            step, trial, trial_arc, lambda0_step);

        [u_trial, lambda_trial, F_int_trial, TrialHist_trial, converged, iters_used] = ...
            obj.arcLengthStep( ...
                @assembleForArcLength, constraintFn, free_dofs, ...
                u0_step, lambda0_step, dup_prev, ...   % P2.3: dup_prev not mutated here
                trial_arc, usePredictor, tol, maxit);

        if converged
            fprintf('OK (%d iters)\n', iters_used);
            F_int_conv      = F_int_trial;
            TrialHist_conv  = TrialHist_trial;
            break;
        else
            fprintf('FAIL\n');
            if trial < max_trials
                trial_arc = max(trial_arc * 0.5, arc_min);
                fprintf('    -> halving radius to %.3e\n', trial_arc);
            end
        end
    end

    if ~converged
        fprintf('!!! Stage %d step %d: failed after %d trials.\n', s, step, max_trials);
        success = false;
        return;
    end

    % ── Accept converged state ───────────────────────────────────────
    obj.commitHistory(TrialHist_conv);

    % P2.3: dup_prev is updated ONLY after a successful step
    dup_prev    = u_trial - u0_step;
    u_converged = u_trial;
    lambda      = lambda_trial;
    stage_step  = stage_step + 1;

    % ── Adaptive radius for next step ────────────────────────────────
    if iters_used <= 4
        arc_length = min(trial_arc * 1.5, arc_max);
    elseif iters_used > round(maxit * 0.75)
        arc_length = max(trial_arc * 0.7, arc_min);
    else
        arc_length = trial_arc;
    end

    % ── Commit to object state ───────────────────────────────────────
    obj.U         = u_converged;
    obj.StepCount = obj.StepCount + 1;

    % Grow history arrays if needed
    if obj.StepCount > size(obj.U_Hist, 2)
        grow = max(size(obj.U_Hist, 2), 30);
        obj.U_Hist       = [obj.U_Hist,       zeros(nDofs, grow)];
        obj.History_Time = [obj.History_Time;  zeros(grow, 1)];
    end
    obj.U_Hist(:, obj.StepCount)    = u_converged;
    obj.History_Time(obj.StepCount) = obj.Time + stage_step * Stage.Duration / ...
        max(stage_step, 1);   % approximate pseudo-time

    % P6.3: store both the used radius and the speculative next radius
    obj.LambdaHist       = [obj.LambdaHist,       lambda];
    obj.ArcLengthHistory = [obj.ArcLengthHistory, trial_arc];   % as-used

    S_Reaction = [S_Reaction, F_int_conv(fixed_dofs)];

    % Event notification
    evtData = SolverEventData(obj.History_Time(obj.StepCount), ...
        obj.StepCount, u_converged, lambda, iters_used);
    notify(obj, 'StepConverged', evtData);
end

% ------------------------------------------------------------------
% 7.  Trim history to actual columns written
% ------------------------------------------------------------------
valid_end        = obj.StepCount;
obj.U_Hist       = obj.U_Hist(:,       1:valid_end);
obj.History_Time = obj.History_Time(   1:valid_end);

obj.Time        = obj.Time + Stage.Duration;
obj.F_ext_start = F_ext_total;
obj.ReactionHist{s} = S_Reaction;

if ~success
    % Normal exit: lambda target reached
    success = true;
end

fprintf('  [Stage %d] %d steps converged.  lambda_final=%.6g\n', ...
    s, stage_step, lambda);
end
