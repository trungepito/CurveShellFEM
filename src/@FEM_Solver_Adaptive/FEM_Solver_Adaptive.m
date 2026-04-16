classdef FEM_Solver_Adaptive < FEM_Solver_Nonlinear
% FEM_SOLVER_ADAPTIVE (Deprecated) 
%
% Use FEM_Solver_Nonlinear instead. This class is maintained for backward 
% compatibility and automatically uses the unified strategy-driven solver.

    methods
        function obj = FEM_Solver_Adaptive(preObj, Options)
            if nargin < 2, Options = SolverOptions(); end
            obj@FEM_Solver_Nonlinear(preObj, Options);
            warning('FEM_Solver_Adaptive is deprecated. Migrate to FEM_Solver_Nonlinear.');
        end
    end
end