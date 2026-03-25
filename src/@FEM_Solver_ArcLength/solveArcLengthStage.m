function success = solveArcLengthStage(obj, Stage, s)
% SOLVEARCLENGTHSTAGE - Arc-length stage driver with adaptive radius.
%
% Processes one LoadingStage using the arc-length method.  The stage
% duration is discretised into arc-length steps.  The arc-length radius
% adapts automatically:
%
%   * Converged in fewer than 5 iterations  -> radius * 1.5  (capped at Max)
%   * Converged normally                    -> radius unchanged
%   * Failed to converge                    -> radius * 0.5, retry (max 5 trials)
%   * All trials exhausted                  -> abort stage
%
% The external load vector is built from Stage.ActiveLoads; displacement
% boundary conditions from Stage.ActiveBCs are applied to the free-dof
% partition, mirroring the convention used in FEM_Solver_Adaptive.
%
% Syntax:
%   success = obj.solveArcLengthStage(Stage, stageIndex)
%
% Inputs:
%   Stage - LoadingStage with arc-length properties set
%   s     - Integer stage index (used for history/event labelling)
%
% Outputs:
%   success - true if all arc-length steps within this stage converged

% ------------------------------------------------------------------
% 0.  Extract stage parameters
% ------------------------------------------------------------------
arc_length  = Stage.ArcLengthRadius;          % Initial / current radius
arc_min     = Stage.ArcLengthMin;
arc_max     = Stage.ArcLengthMax;
max_trials  = 5;                              % Max re-tries per step
usePredictor = strcmp(Stage.ConstraintType, 'Riks');  % Predictor only needed for Riks

tol    = obj.Options.Tolerance;
maxit  = obj.Options.MaxIterations;

% ------------------------------------------------------------------
% 1.  Build the total external load vector for this stage
%     (mirrors FEM_Solver_Adaptive.calculateGlobalTargetForce)
% ------------------------------------------------------------------
F_ext_total = obj.calculateGlobalTargetForce(Stage.ActiveLoads);

% ------------------------------------------------------------------
% 2.  Resolve displacement-control DOFs (ActiveBCs)
%     Fixed DOFs are removed from the Newton system; their targets
%     are embedded directly in the solution vector.
% ------------------------------------------------------------------
[fixed_dofs, disp_targets] = getDispload(obj, Stage.ActiveBCs);
nDofs       = length(obj.U);
free_dofs   = setdiff(1:nDofs, fixed_dofs);

% Apply prescribed displacements to U for the first predictor step
U_stage_start = obj.U;
U_stage_start(fixed_dofs) = disp_targets;

% ------------------------------------------------------------------
% 3.  Build an assembly function handle that matches the sample
%     arc_length_solver.m signature:
%         [R, KT, fext, hist] = func(u, lambda, hist, nri)
%     where:
%       R    = F_int(u) - lambda*F_ext  (residual, zero at equilibrium)
%       KT   = tangent stiffness
%       fext = external load vector (unscaled, for norm reference)
%
%     We use obj.assembleTangentSystem which is inherited from FEM_Solver.
%     History is handled internally by the element cache (plasticity),
%     so hist is passed as a dummy integer counter here.
% ------------------------------------------------------------------
function [R, KT, fext, hist_out] = assembleArcLength(u_in, lambda_in, hist_in, ~)
    obj.U = u_in;
    [KT_full, F_int] = obj.assembleTangentSystem(u_in);

    % Apply displacement BCs via penalty / zeroing of fixed rows
    % (Homogeneous enforcement: prescribed DOFs hold their target values)
    fext = F_ext_total;
    R    = F_int - lambda_in * F_ext_total;

    % Zero residual at fixed DOFs (they are not solved for)
    R(fixed_dofs) = 0;

    hist_out = hist_in;
    KT       = KT_full;
end

% ------------------------------------------------------------------
% 4.  Select constraint function handle from ConstraintType
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
            'Unknown ConstraintType ''%s''; defaulting to Riks.', ...
            obj.ConstraintType);
        constraintFn = @(u,l,u0,l0,dup,dlp,si) ...
            obj.crisfieldConstraint(u,l,u0,l0,dup,dlp,si);
end

% ------------------------------------------------------------------
% 5.  Determine number of arc-length steps for this stage.
%     The stage duration is treated as a load-factor increment target.
%     Steps continue until time reaches stage end.
% ------------------------------------------------------------------
t_start  = obj.Time;
t_end    = t_start + Stage.Duration;

% Current load factor lambda (0 = unloaded, 1 = full Stage.Duration applied)
lambda        = 0;   % lambda is dimensionless [0, 1] within the stage
u_converged   = U_stage_start;
funcHandle    = @assembleArcLength;

stage_step   = 0;       % Step counter within this stage
success      = false;   % Will be set true when t_end is reached
S_Reaction   = [];      % Reaction force history for this stage

fprintf('    ArcLength radius: %.2e  [%.2e, %.2e]  Constraint: %s\n', ...
    arc_length, arc_min, arc_max, obj.ConstraintType);

% ------------------------------------------------------------------
% 6.  Main arc-length stepping loop
% ------------------------------------------------------------------
while obj.Time < t_end

    % Snapshot state before this step (for rollback on failure)
    u0_step     = u_converged;
    lambda0_step = lambda;

    % --- Trial loop (adaptive radius) ---
    trial_arc   = arc_length;
    converged   = false;
    iters_used  = 0;

    for trial = 1:max_trials

        fprintf('   Step %d  trial %d/%d  radius=%.3e  lambda=%.4f ... ', ...
            stage_step+1, trial, max_trials, trial_arc, lambda0_step);

        [u_trial, lambda_trial, converged, iters_used] = obj.arcLengthStep( ...
            funcHandle, constraintFn, ...
            u0_step, lambda0_step, ...
            trial_arc, usePredictor, tol, maxit);

        if converged
            fprintf('OK  (%d iters)\n', iters_used);
            break;
        else
            fprintf('FAIL\n');
            if trial < max_trials
                trial_arc = max(trial_arc * 0.5, arc_min);
                fprintf('         Reducing radius to %.3e\n', trial_arc);
            end
        end
    end

    % --- Check whether the step ultimately converged ---
    if ~converged
        fprintf('!!! Stage %d: step %d did not converge after %d trials.\n', ...
            s, stage_step+1, max_trials);
        success = false;
        return;
    end

    % --- Accept the converged state ---
    u_converged   = u_trial;
    lambda        = lambda_trial;
    stage_step    = stage_step + 1;

    % --- Adaptive radius update for the NEXT step ---
    if iters_used <= 4
        arc_length = min(trial_arc * 1.5, arc_max);
    elseif iters_used > obj.Options.MaxIterations * 0.75
        arc_length = max(trial_arc * 0.7, arc_min);
    else
        arc_length = trial_arc;   % Converged in normal range — keep radius
    end

    % --- Advance pseudo-time proportionally to lambda increment ---
    delta_lambda  = abs(lambda - lambda0_step);
    obj.Time      = min(obj.Time + delta_lambda * Stage.Duration, t_end);

    % --- Store converged displacement in object ---
    obj.U         = u_converged;
    obj.StepCount = obj.StepCount + 1;

    % --- Grow U_Hist dynamically (doubles capacity like FEM_Solver_Adaptive) ---
    if obj.StepCount > size(obj.U_Hist, 2)
        obj.U_Hist = [obj.U_Hist, zeros(nDofs, max(size(obj.U_Hist,2), 30))];
    end
    obj.U_Hist(:, obj.StepCount) = u_converged;

    if obj.StepCount > length(obj.History_Time)
        obj.History_Time = [obj.History_Time; zeros(max(length(obj.History_Time),30),1)];
    end
    obj.History_Time(obj.StepCount) = obj.Time;

    % Append to lambda and arc-length histories
    obj.LambdaHist       = [obj.LambdaHist,       lambda];
    obj.ArcLengthHistory = [obj.ArcLengthHistory,  arc_length];

    % Reaction forces at fixed DOFs
    [~, F_int_conv] = obj.assembleTangentSystem(u_converged);
    reaction_vec    = F_int_conv(fixed_dofs);
    S_Reaction      = [S_Reaction, reaction_vec(:)];

    % --- Fire StepConverged event (compatible with FEM_Solver_Adaptive listeners) ---
    evtData = SolverEventData(obj.Time, obj.StepCount, u_converged, lambda, iters_used);
    notify(obj, 'StepConverged', evtData);

    % --- Check for stage completion ---
    if abs(obj.Time - t_end) < 1e-9
        break;
    end
end

% ------------------------------------------------------------------
% 7.  Trim history to actual length and store stage reactions
% ------------------------------------------------------------------
obj.U_Hist       = obj.U_Hist(:, 1:obj.StepCount);
obj.History_Time = obj.History_Time(1:obj.StepCount);
obj.ReactionHist{s} = S_Reaction;

% Update the external load baseline for the next stage
% (mirrors FEM_Solver_Adaptive.solveStage)
obj.F_ext_start = F_ext_total;

success = true;
fprintf('    Stage %d complete — %d steps converged.\n', s, stage_step);
end
