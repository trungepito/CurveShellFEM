classdef Curve8Element_Plastic < Curve8Element
    properties
        MaterialModel % Instance of Material_J2Plastic
        HistoryData   % Struct array containing 'eps_p' for integration points
    end
    
    methods
        function obj = Curve8Element_Plastic(coords, normals, t, matModel, history)
            obj@Curve8Element(coords, normals, t, matModel.E, matModel.nu);
            obj.MaterialModel = matModel;
            obj.HistoryData = history; 
        end
    end
    methods
        
        [KT, F_int, NewHistory] = computeTangentStiffnessAndForce(obj, u_elem)

         % Helper to encapsulate the messy B-matrix logic from previous steps
        [detJ, Bm0, Bb0, Bs0, G] = calculateKinematics(obj, xi, eta)
    end
end