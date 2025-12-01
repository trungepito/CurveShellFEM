classdef FEM_Solver < handle
    properties
        Model           % Reference to Preprocessor object
        GlobalK         % Stiffness Matrix
        GlobalKg        % Geometric Stiffness Matrix (for buckling)
        GlobalF         % Force Vector
        U               % Displacement Vector (Solution)
        ModeShapes      % Buckling solutions
        BucklingFactors % Eigenvalues
    end

    methods
        function obj = FEM_Solver(preprocessorObj)
            obj.Model = preprocessorObj;
        end
    end
    methods
        solveStatic(obj)
        solveBuckling(obj, numModes)
        solveNonLinear(obj, numLoadSteps, maxIter, tol)
    end

    methods(Access = private)
        assembleK(obj)
        assembleKg(obj)
        applyLoads(obj)
        applyConstraints(obj)
        [KT, F_int] = assembleTangentSystem(obj)
    end
end
