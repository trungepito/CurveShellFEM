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
    end

    methods
        function obj = FEM_Postprocessor(preObj, solvObj)
            obj.Model = preObj;
            obj.Solver = solvObj;
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
        values = recoverPlasticFront(obj)
        animateDisplacement(obj, scale,speed, SaveVideo, VideoName)
        animateScenario(obj, plotNodeID, plotDOF, scaleFactor, speed)
    end

end