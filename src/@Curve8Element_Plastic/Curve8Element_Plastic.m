classdef Curve8Element_Plastic < Curve8Element
% CURVE8ELEMENT_PLASTIC - Stateful 8-node shell element with J2 Plasticity.
%
% This element stores history variables (plastic strain) at every integration 
% point and performs through-thickness integration to capture partial yielding.

    properties
        MaterialModel % Instance of Material_J2Plastic
        HistoryData   % Struct array containing 'sigma' and 'p' for integration points
    end
    
    methods
        function obj = Curve8Element_Plastic(coords, normals, t, matModel, history)
            obj@Curve8Element(coords, normals, t, matModel.E, matModel.nu);
            obj.MaterialModel = matModel;
            obj.HistoryData = history; 
        end
    end
    
    methods(Access=protected)
        [KT, F_int, NewHistory] = computeTangentStiffnessAndForce(obj, u_elem)
    end
end