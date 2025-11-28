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
        plotField(obj, fieldType, layer)
        values = recoverNodalSmooth(obj, type, layer)
        [val, tensor] = evaluatePoint(obj, elObj, u_el, xi, eta, z, type, elemID)
        renderPlot(obj, values, titleStr)
        plotPrincipalVectors(obj, layer)
    end

end