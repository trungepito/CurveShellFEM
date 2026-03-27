function solve(obj, StageList)
% SOLVE  Master arc-length analysis loop over a cell array of LoadingStages.
%
% Overrides FEM_Solver_Adaptive.solve.  Every stage is routed through
% solveArcLengthStage instead of the standard Newton bisection path.
%
% History arrays (LambdaHist, ArcLengthHistory, U_Hist) are reset at the
% start of every call so the object can be reused without stale data.
%
% Syntax:
%   obj.solve(StageList)
%
% See also: solveArcLengthStage, arcLengthStep

fprintf('=== Arc-Length Analysis  [%d stage(s), default constraint: %s] ===\n', ...
    length(StageList), obj.ConstraintType);

% ------------------------------------------------------------------
% Reset all history so re-running on the same object starts clean.
% FIX: previous version did not reset obj.U, leaving stale displacements
% as the initial condition for the first predictor step.
% ------------------------------------------------------------------
nDofs                = size(obj.Model.Mesh.Nodes, 1) * 6;
obj.U                = zeros(nDofs, 1);
obj.LambdaHist       = [];
obj.ArcLengthHistory = [];
obj.U_Hist           = zeros(nDofs, 0);   % grows column-by-column
obj.History_Time     = [];
obj.StepCount        = 0;
obj.Time             = 0;
obj.F_ext_start      = zeros(nDofs, 1);

for s = 1 : length(StageList)
    Stage = StageList{s};
    fprintf('\n>>> Stage %d / %d\n', s, length(StageList));

    % Apply stage-level overrides for constraint type and control DOF.
    % isprop guards against plain structs being passed instead of
    % LoadingStage objects.
    if isprop(Stage, 'ConstraintType') && ~isempty(Stage.ConstraintType)
        obj.ConstraintType = Stage.ConstraintType;
    end
    if isprop(Stage, 'ControlDOF') && ~isempty(Stage.ControlDOF)
        obj.ControlDOF = Stage.ControlDOF;
    end

    success = obj.solveArcLengthStage(Stage, s);

    if ~success
        fprintf('!!! Analysis aborted at stage %d.\n', s);
        return;
    end
end

fprintf('\n=== Arc-Length Analysis complete — %d converged steps total ===\n', ...
    obj.StepCount);
end
