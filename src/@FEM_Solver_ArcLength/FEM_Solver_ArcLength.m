classdef FEM_Solver_ArcLength < FEM_Solver_Nonlinear
% FEM_SOLVER_ARCLENGTH (Deprecated)
%
% Use FEM_Solver_Nonlinear instead. This class is maintained for backward 
% compatibility and automatically uses the unified strategy-driven solver.
% Arc-length parameters are now set on the LoadingStage or via strategies.

    methods
        function obj = FEM_Solver_ArcLength(preObj, Options)
            if nargin < 2, Options = SolverOptions(); end
            obj@FEM_Solver_Nonlinear(preObj, Options);
            warning('FEM_Solver_ArcLength is deprecated. Migrate to FEM_Solver_Nonlinear.');
        end
    end
end
