classdef FEM_Solver < handle
% FEM_SOLVER - Base implementation for linear static and nonlinear analysis.
%
% Enhancement log (P4.1):
%   KT_is_elastic_constant property added.  Set to true by
%   assembleTangentSystem when the material model is linear-elastic
%   (no J2Plastic type), allowing the arc-length corrector to skip
%   KT re-assembly on iterations 2..maxit and call
%   assembleinternalforceONLY instead.

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

        % P4.1: set by assembleTangentSystem; read by arcLengthStep
        % true  => material is linear-elastic; KT is constant within a step
        % false => J2-plastic; KT must be re-assembled every iteration
        KT_is_elastic_constant = false
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
                if isprop(obj.Elements{e}, 'HistoryData')
                    obj.Elements{e}.HistoryData = TrialHist{e};
                end
            end
        end
    end
    methods
        function buildElementCache(obj)
            % BUILDELEMENTCACHE Pre-builds element objects and scatter maps
            m   = obj.Model.Mesh;
            mat = obj.Model.Material;
            nElems = size(m.Elements, 1);
            obj.Elements = cell(nElems, 1);
            obj.SctrMap  = zeros(nElems, 48);
            for e = 1:nElems
                idx        = m.Elements(e, :);
                el_coords  = m.Nodes(idx, :);
                el_normals = m.Normals(idx, :);
                useANS_EAS = isfield(mat, 'ElementType') && strcmp(mat.ElementType, 'ANS_EAS');

                if isfield(mat, 'Type') && strcmp(mat.Type, 'J2Plastic') && isfield(mat, 'Obj')
                    nGP    = 4 * 5;
                    init_h = struct('sigma', zeros(3,1), 'eps_p', zeros(3,1), 'p', 0);
                    hist   = repmat(init_h, nGP, 1);
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
                    start_dof  = (double(idx(n)) - 1) * 6;
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
