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
        
        function commitHistory(obj, TrialHist)
            % COMMITHISTORY - Finalizes the plastic state for the current increment.
            if isempty(TrialHist), return; end
            for e = 1:length(obj.Elements)
                % Check if element has HistoryData property (Phase 10)
                if isprop(obj.Elements{e}, 'HistoryData')
                    obj.Elements{e}.HistoryData = TrialHist{e};
                end
            end
        end
    end
    methods
        function buildElementCache(obj)
            % BUILDELEMENTCACHE Pre-builds element objects and scatter maps
            m = obj.Model.Mesh;
            mat = obj.Model.Material;
            nElems = size(m.Elements, 1);
            obj.Elements = cell(nElems, 1);
            obj.SctrMap = zeros(nElems, 48);
            for e = 1:nElems
                idx = m.Elements(e, :);
                el_coords = m.Nodes(idx, :);
                el_normals = m.Normals(idx, :);
                % Phase 9/10 Dynamic Element Selection
                useANS_EAS = isfield(mat, 'ElementType') && strcmp(mat.ElementType, 'ANS_EAS');
                
                if isfield(mat, 'Type') && strcmp(mat.Type, 'J2Plastic') && isfield(mat, 'Obj')
                    nGP = 4 * 5; 
                    init_h = struct('sigma', zeros(3,1), 'eps_p', zeros(3,1), 'p', 0);
                    hist = repmat(init_h, nGP, 1);
                    if useANS_EAS
                        obj.Elements{e} = Curve8Element_ANS_EAS(el_coords, el_normals, mat.t, mat.E, mat.nu, mat.Obj, hist);
                    else
                        obj.Elements{e} = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu, mat.Obj, hist);
                    end
                else
                    if useANS_EAS
                        obj.Elements{e} = Curve8Element_ANS_EAS(el_coords, el_normals, mat.t, mat.E, mat.nu);
                    else
                        obj.Elements{e} = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu);
                    end
                end
                sctr = zeros(1, 48);
                for n = 1:8
                    start_dof = (double(idx(n)) - 1) * 6;
                    local_start = (n - 1) * 6;
                    sctr(local_start+1 : local_start+6) = start_dof + (1:6);
                end
                obj.SctrMap(e, :) = sctr;
            end
        end
        [KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)
        F_int = assembleinternalforceONLY(obj, U_trial)
    end
end
