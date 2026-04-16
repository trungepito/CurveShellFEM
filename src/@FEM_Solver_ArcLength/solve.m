function solve(obj, StageList)
% SOLVE  Deprecated — use FEM_Solver_Nonlinear.solve() directly.
%
% This wrapper exists for backward compatibility. FEM_Solver_ArcLength
% will be removed in v4. Migrate to FEM_Solver_Nonlinear with strategy
% objects on LoadingStage.
%
% See also: FEM_Solver_Nonlinear.solve, IncrementalStrategy

warning('FEM_Solver_ArcLength:deprecated', ...
    'Use FEM_Solver_Nonlinear.solve() directly. FEM_Solver_ArcLength will be removed in v4.');

% Reset state for clean start (preserve existing behavior)
nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
obj.U = zeros(nDofs, 1);
obj.LambdaHist = [];
obj.ArcLengthHistory = [];
obj.StepCount = 0;
obj.Time = 0;
obj.F_ext_start = zeros(nDofs, 1);

% Ensure each stage has an appropriate strategy from legacy properties
for s = 1:length(StageList)
    Stage = StageList{s};
    if isempty(Stage.strategy)
        % Copy solver-level constraint settings to stage if not set
        if isprop(Stage, 'ConstraintType') && isempty(Stage.ConstraintType)
            Stage.ConstraintType = obj.ConstraintType;
        end
        if isprop(Stage, 'ControlDOF') && isempty(Stage.ControlDOF) && ~isempty(obj.ControlDOF)
            Stage.ControlDOF = obj.ControlDOF;
        end
    end
end

% Delegate to unified solve
solve@FEM_Solver_Nonlinear(obj, StageList);
end
