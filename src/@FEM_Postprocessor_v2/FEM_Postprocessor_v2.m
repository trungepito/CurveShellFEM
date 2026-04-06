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
        Solver      % FEM_Solver (any subclass) handle
    end

    properties (Access = private)
        % Cache: avoid re-integrating GP data for repeated field requests
        % on the same step.
        CachedStep  = -1
        CachedGP    = {}   % cell[nElems x 1] of gpData struct arrays
    end

    methods
        function obj = FEM_Postprocessor_v2(model, solver)
            % FEM_POSTPROCESSOR  Construct a postprocessor.
            %
            % Usage:
            %   Post = FEM_Postprocessor(Pre, Sol)
            %   Post = FEM_Postprocessor(Sol.Model, Sol)   % equivalent
            if nargin == 1 && isa(model, 'FEM_Solver')
                % Convenience: accept a solver as the only argument
                obj.Solver = model;
                obj.Model  = model.Model;
            else
                obj.Model  = model;
                obj.Solver = solver;
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
