classdef FEM_Postprocessor_v2 < handle
% FEM_POSTPROCESSOR  Consistent stress recovery and visualisation.
%
% Architecture (v2)
% -----------------
% All stress fields are recovered through a strict two-stage pipeline:
%
%   Stage 1 — Gauss-point recovery (element-local, lossless)
%     recoverAllGaussPoints(stepIdx)
%       Loops over elements and calls Curve8Element.recoverGaussPointData.
%       Returns a [nElems x 1] cell array, each cell a [20x1] gpData struct.
%       Plastic elements read HistoryData; elastic elements re-integrate.
%
%   Stage 2 — Nodal projection (SPR)
%     recoverNodalSPR(gpCell, fieldName)
%       For each node, gathers all element patches that share it,
%       fits a least-squares polynomial to the Gauss-point values,
%       and evaluates the polynomial at the node position.
%       Returns a [nNodes x 1] vector of smoothed nodal values.
%
% Public API
% ----------
%   field = Post.recoverField(fieldName, stepIdx)
%   [errEl, totalNorm] = Post.estimateErrorNorms(stepIdx)
%   Post.plotField(fieldName, stepIdx)
%   Post.plotPlasticYield(stepIdx)
%   Post.animateHistory(nodeID, dofIdx)
%   Post.plotReactionDispCurve(reactionHist, dispNodeID, dispDOF, stageIdx)
%
% Supported fieldName strings
% ---------------------------
%   'displacement_x'  'displacement_y'  'displacement_z'
%   'sigma_x'         'sigma_y'         'tau_xy'
%   'von_mises'       'sigma_1'         'sigma_2'
%   'eps_p'           'p'               'yield_depth'
%
% See also: Curve8Element/recoverGaussPointData, FEM_Solver

    properties (SetAccess = private)
        Model       % FEM_Preprocessor_v2 handle
        Snapshot    % SolutionSnapshot (immutable value object)
        
        % Core solver data needed for recovery (Wave 2 encapsulation)
        Elements    % cell[nElems x 1] of element handles
        SctrMap     % [nElems x 48] global DOF mapping
    end

    properties (Access = private)
        % Cache: avoid re-integrating GP data for repeated field requests
        % on the same step.
        CachedStep  = -1
        CachedGP    = {}   % cell[nElems x 1] of gpData struct arrays
    end

    methods
        function obj = FEM_Postprocessor_v2(model, solverOrSnapshot)
            % FEM_POSTPROCESSOR  Construct a postprocessor.
            %
            % Usage:
            %   Post = FEM_Postprocessor_v2(Pre, Sol)
            %   Post = FEM_Postprocessor_v2(Sol) % shortcut
            
            if nargin == 1 && isa(model, 'FEM_Solver')
                sol = model;
                obj.Model = sol.Model;
                obj.Snapshot = sol.state.snapshot();
                obj.Elements = sol.Elements;
                obj.SctrMap  = sol.SctrMap;
            elseif nargin == 2
                obj.Model = model;
                if isa(solverOrSnapshot, 'FEM_Solver')
                    obj.Snapshot = solverOrSnapshot.state.snapshot();
                    obj.Elements = solverOrSnapshot.Elements;
                    obj.SctrMap  = solverOrSnapshot.SctrMap;
                elseif isa(solverOrSnapshot, 'SolutionSnapshot')
                    obj.Snapshot = solverOrSnapshot;
                    % Note: Elements/SctrMap must be provided via 
                    % separate mechanism or the solver reconstructed
                    % if loading from disk.
                else
                    error('Postprocessor requires a Solver or SolutionSnapshot.');
                end
            end
        end
    end

    % ====================================================================
    % PRIMARY PUBLIC API
    % ====================================================================
    methods
        field = recoverField(obj, fieldName, stepIdx)
        [errEl, totalNorm] = estimateErrorNorms(obj, stepIdx)
        plotField(obj, fieldName, stepIdx)
        plotPlasticYield(obj, stepIdx)
        animateHistory(obj, nodeID, dofIdx)
        plotReactionDispCurve(obj, reactionHist, dispNodeID, dispDOF, stageIdx)
        tf = hasArchive(obj, stepIdx)
    end

    % ====================================================================
    % INTERNAL PIPELINE — called by public methods
    % ====================================================================
    methods (Access = private)
        gpCell = recoverAllGaussPoints(obj, stepIdx)
        nodalVals = recoverNodalSPR(obj, gpCell, fieldName)
        nodalVals = recoverNodalAverage(obj, gpCell, fieldName)  % fallback
        U = getDisplacementAtStep(obj, stepIdx)
        raw = extractGPScalar(obj, gpCell, fieldName)
    end
end
