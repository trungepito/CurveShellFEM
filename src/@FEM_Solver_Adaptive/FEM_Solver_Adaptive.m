classdef FEM_Solver_Adaptive < FEM_Solver_Nonlinear

    properties
        F_ext_start       % external for at start of each stage!
        ReactionHist
        History_Load      % Number of steps taken
    end

    methods
        function obj = FEM_Solver_Adaptive(preObj, Options)
            obj@FEM_Solver_Nonlinear(preObj, Options);
            nDofs = length(obj.U);
            obj.F_ext_start = zeros(nDofs, 1);
        end
    end
    
    methods
        solve(obj, StageList)
    end

    methods (Access = protected)
        success = solveStage(obj, Stage, s)
    end
end