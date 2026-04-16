function success = solveArcLengthStage(obj, Stage, s)
% SOLVEARCLENGTHSTAGE  Arc-length stage driver with E4 curvature-aware radius.
%
% Enhancement E4 replaces the original three-branch iteration-count heuristic
% with a continuous formula combining:
%
%   Ramm (1981) iteration-optimal factor:
%       fac_iters = sqrt(I_des / I_used)
%
%   Bergan (1980) path-curvature factor:
%       cos_theta = dot(dup_prev, dup_curr) / (||dup_prev|| * ||dup_curr||)
%       fac_curv  = 0.5 * (1 + cos_theta)    maps [-1,1] -> [0,1]
%       floor at 0.25 (never reduce by more than 75% in one step)
%
%   Combined via weighted geometric mean:
%       arc_new = trial_arc * fac_iters^(1-w) * fac_curv^w
%
% where w = opts.ArcCurvatureWt (default 0.4).
%
% cos_theta = 1  : straight path    -> fac_curv = 1.0  (no reduction)
% cos_theta = 0  : right-angle turn -> fac_curv = 0.5  (moderate reduction)
% cos_theta = -1 : reversal (snap)  -> fac_curv = 0.25 (aggressive reduction)
%
% All other logic (stage parameters, assembly closure, constraint selection,
% trial loop, history storage, event notification) is unchanged from v3.0.
%
% See also: arcLengthStep, SolverOptions, FEM_Solver_ArcLength

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

nSteps = max(1, ceil(Stage.Duration / arc_length));

% ------------------------------------------------------------------
% 1.  External load vector
% ------------------------------------------------------------------
F_ext_total = obj.calculateGlobalTargetForce(Stage.ActiveLoads);

% ------------------------------------------------------------------
% 2.  Displacement BCs and free-DOF partition
% ------------------------------------------------------------------
[fixed_dofs, disp_targets] = getDispload(obj, Stage.ActiveBCs);
nDofs     = length(obj.U);
free_dofs = setdiff(1:nDofs, fixed_dofs)';

U_stage_start               = obj.U;
U_stage_start(fixed_dofs)   = disp_targets;

% ------------------------------------------------------------------
% 3.  Assembly closure
% ------------------------------------------------------------------
    function [R, KT, fext, TrialHist] = assembleForArcLength(u_in, lambda_in, ~, ~)
        [KT_full, F_int, TrialHist] = obj.assembleTangentSystem(u_in);
        fext = F_ext_total;
        R    = F_int - lambda_in * fext;
        R(fixed_dofs) = 0;
        KT   = KT_full;
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
dup_prev    = zeros(nDofs, 1);
stage_step  = 0;
col_start   = obj.StepCount;
S_Reaction  = zeros(length(fixed_dofs), 0);

fprintf('    radius=%.2e [%.2e,%.2e]  nSteps~%d  lambda0=%.4f  constraint=%s\n', ...
    arc_length, arc_min, arc_max, nSteps, lambda, obj.ConstraintType);

% ------------------------------------------------------------------
% 6.  Main stepping loop
% ------------------------------------------------------------------
success = false;

for step = 1 : nSteps

    u0_step      = u_converged;
    lambda0_step = lambda;

    trial_arc  = arc_length;
    converged  = false;
    iters_used = 0;
    F_int_conv = zeros(nDofs, 1);
    dup_curr   = zeros(nDofs, 1);   % predictor direction of this step

    for trial = 1 : max_trials
        fprintf('   step %d/%d  trial %d  ds=%.3e  lambda=%.4f ... ', ...
            step, nSteps, trial, trial_arc, lambda0_step);

        [u_trial, lambda_trial, F_int_trial, TrialHist_trial, converged, iters_used] = ...
            obj.arcLengthStep( ...
            @assembleForArcLength, constraintFn, free_dofs, ...
            u0_step, lambda0_step, dup_prev, ...
            trial_arc, usePredictor, tol, maxit);

        if converged
            fprintf('OK (%d iters)\n', iters_used);
            F_int_conv     = F_int_trial;
            TrialHist_conv = TrialHist_trial;
            % Record the predictor direction for E4 curvature computation
            dup_curr       = u_trial - u0_step;
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

    % ---- Accept converged state ----
    obj.commitHistory(TrialHist_conv);
    u_converged = u_trial;
    lambda      = lambda_trial;
    stage_step  = stage_step + 1;

    % ------------------------------------------------------------------
    % E4 — Curvature-aware radius adaptation
    % ------------------------------------------------------------------
    % Ramm (1981) iteration-optimal factor
    I_des     = obj.Options.DesiredIters;
    fac_iters = sqrt(I_des / max(iters_used, 1));

    % Bergan (1980) path-curvature factor
    if norm(dup_prev(free_dofs)) > 1e-12 && norm(dup_curr(free_dofs)) > 1e-12
        cos_theta = dot(dup_prev(free_dofs), dup_curr(free_dofs)) / ...
                    (norm(dup_prev(free_dofs)) * norm(dup_curr(free_dofs)));
        cos_theta = max(-1.0, min(1.0, cos_theta));   % clamp numerical noise
        % Symmetric map: cos=1 -> 1.0, cos=0 -> 0.5, cos=-1 -> 0.0
        % Floor at 0.25 prevents catastrophic radius collapse in one step
        fac_curv  = max(0.5 * (1.0 + cos_theta), 0.25);
    else
        fac_curv  = 1.0;
    end

    % Weighted geometric mean of the two factors
    w          = obj.Options.ArcCurvatureWt;   % default 0.4
    fac_total  = fac_iters^(1-w) * fac_curv^w;
    arc_length = min(max(trial_arc * fac_total, arc_min), arc_max);

    % Update predictor direction for next step
    dup_prev = dup_curr;

    % ---- Commit to object state ----
    obj.U         = u_converged;
    obj.StepCount = obj.StepCount + 1;

    % ---- History storage ----
    if obj.StepCount > size(obj.U_Hist, 2)
        grow             = max(size(obj.U_Hist, 2), 30);
        obj.U_Hist       = [obj.U_Hist,       zeros(nDofs, grow)];
        obj.History_Time = [obj.History_Time;  zeros(grow, 1)];
    end
    obj.U_Hist(:, obj.StepCount)    = u_converged;
    obj.History_Time(obj.StepCount) = obj.Time + step * Stage.Duration / nSteps;

    obj.LambdaHist       = [obj.LambdaHist,       lambda];
    obj.ArcLengthHistory = [obj.ArcLengthHistory,  trial_arc];

    S_Reaction = [S_Reaction, F_int_conv(fixed_dofs)]; %#ok<AGROW>

    % ---- Event notification ----
    evtData = SolverEventData(obj.History_Time(obj.StepCount), ...
        obj.StepCount, u_converged, lambda, iters_used);
    notify(obj, 'StepConverged', evtData);
end

% ------------------------------------------------------------------
% 7.  Trim history to actual columns written
% ------------------------------------------------------------------
obj.U_Hist       = obj.U_Hist(:,    1:obj.StepCount);
obj.History_Time = obj.History_Time(1:obj.StepCount);

obj.Time         = obj.Time + Stage.Duration;
obj.F_ext_start  = F_ext_total;
obj.ReactionHist{s} = S_Reaction;

success = true;
fprintf('    Stage %d: %d steps converged.  lambda_final = %.4f\n', ...
    s, stage_step, lambda);
end
