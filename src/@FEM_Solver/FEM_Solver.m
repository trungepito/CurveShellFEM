classdef FEM_Solver < handle
    % FEM_SOLVER - The base implementation for linear static analysis.
    %
    % This class handles global matrix assembly, constraint application via
    % reduced-DOF systems, and linear system solving.
    %
    % Usage:
    %   Sol = FEM_Solver(PreprocessorObj)
    %   Sol.solveStatic()
    %
    % See also: FEM_Solver_NL, FEM_Preprocessor_v2

    properties
        Model           % Reference to Preprocessor object
        GlobalK         % Stiffness Matrix
        GlobalKg        % Geometric Stiffness Matrix (for buckling)
        GlobalF         % Force Vector
        U               % Displacement Vector (Solution)
        ModeShapes      % Buckling solutions
        BucklingFactors % Eigenvalues
        Elements        % Cell array of pre-built element objects
        SctrMap         % Pre-computed scatter index map (nElems x 48)
        FreeDofs        % Indices of unconstrained degrees of freedom
    end

    events
        Lin_sol         % linear solution is done for both linear and buckling 
    end

    methods
        function obj = FEM_Solver(preprocessorObj)
            obj.Model = preprocessorObj;
            obj.buildElementCache();
        end
    end

    methods
        solveStatic(obj)
        solveBuckling(obj, numModes)
        solveStaticDisplacement(obj)
        tf = hasMaterialPlastic(obj)
    end

    methods(Access = protected)
        commitHistory(obj, TrialHist)
        buildElementCache(obj)
        [KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)
        F_int = assembleinternalforceONLY(obj, U_trial)
    end
    
    methods (Access = public)
        assembleK(obj)
        assembleKg(obj)
    end
end
