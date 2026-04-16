function solve(obj, StageList)
% SOLVE  Deprecated — use FEM_Solver_Nonlinear.solve() directly.
%
% This wrapper exists for backward compatibility. FEM_Solver_Adaptive
% will be removed in v4. Migrate to FEM_Solver_Nonlinear.

warning('FEM_Solver_Adaptive:deprecated', ...
    'Use FEM_Solver_Nonlinear.solve() directly. FEM_Solver_Adaptive will be removed in v4.');

% Delegate to unified solve on FEM_Solver_Nonlinear
solve@FEM_Solver_Nonlinear(obj, StageList);
end