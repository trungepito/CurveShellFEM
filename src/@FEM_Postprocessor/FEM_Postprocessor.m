classdef FEM_Postprocessor < handle
% FEM_POSTPROCESSOR - Results extraction and mathematical recovery engine.
%
% Handles vectorized Superconvergent Recovery (SPR) of stresses and 
% displacements. Supports through-thickness layer evaluation and 
% automated plotting.
%
% Usage:
%   Post = FEM_Postprocessor(SolverObj)
%   sigma = Post.recoverNodalSmooth('SigmaX', 'Mid')
%
% See also: FEM_Postprocessor_App, FEM_Solver
    properties
        Model   % Preprocessor Reference
        Solver  % Solver Reference
        v2delegate % New internal v2 equivalent
    end

    methods
        function obj = FEM_Postprocessor(preObj, solvObj)
            warning('FEM_Postprocessor:deprecated', ...
                ['FEM_Postprocessor v1 is deprecated. ' ...
                 'Migrate to FEM_Postprocessor_v2. ' ...
                 'v1 will be removed in the next major version.']);
            obj.Model  = preObj;
            obj.Solver = solvObj;
            % Build internal v2 delegate if solver has new state
            if isprop(solvObj, 'state') && ~isempty(solvObj.state)
                obj.v2delegate = FEM_Postprocessor_v2(preObj, solvObj.state.snapshot());
            end
        end
    end
    
    methods
        plotField(obj, fieldType, opts)
        values = recoverNodalSmooth(obj, type, layer)
        [val, tensor] = evaluatePoint(obj, elObj, u_el, xi, eta, z, type, elemID)
        renderPlot(obj, values, fieldType,opts)
        plotPrincipalVectors(obj, layer)
        plotLoadDisplacement(obj, nodeID, dofID)
        plotReactionDispCurve(obj, controlNodeID, controlDOF)
        values = recoverNodalStressSPR(obj, type, layer)
        [error_norm_el, total_error] = estimateErrorNorms(obj)
        animateDisplacement(obj, scale,speed, SaveVideo, VideoName)
        animateScenario(obj, plotNodeID, plotDOF, scaleFactor, speed)
    end

end