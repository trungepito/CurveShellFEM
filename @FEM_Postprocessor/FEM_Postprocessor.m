classdef FEM_Postprocessor < handle
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
        animateDisplacement(obj, scale,speed, SaveVideo, VideoName)
        animateScenario(obj, plotNodeID, plotDOF, scaleFactor, speed)
    end

end