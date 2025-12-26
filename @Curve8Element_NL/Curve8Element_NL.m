classdef Curve8Element_NL < Curve8Element
    % properties
    %     % MaterialModel % Instance of Material_J2Plastic
    %     % HistoryData   % Struct array containing 'eps_p' for integration points
    % end

    methods
        function obj = Curve8Element_NL(coords, normals, t, E, nu)
            obj@Curve8Element(coords, normals, t, E,nu);
            % obj.HistoryData = history;
        end
    end

    methods(Access=private)
        [KT, F_int] = computeTangentStiffnessAndForce(obj, u_elem)
        F_int = computeintForce(obj, u_elem)

    end
    methods
        [KT_global,F_int] = computeGlobalMatrix6DOF(obj,u_el)
        F_int = computeGlobalForceONLY(obj,u_el)
    end
end