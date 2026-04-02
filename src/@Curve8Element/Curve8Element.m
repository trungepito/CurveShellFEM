classdef Curve8Element
% CURVE8ELEMENT - Stateless mathematical engine for curved 8-node shell elements.
%
% Handles the 40-DOF mixed-basis formulation and transformation to the 
% 48-DOF global coordinate system.
%
% Usage:
%   el = Curve8Element(coords, normals, t, E, nu)
%   Ke = el.computeGlobalMatrix6DOF()
%
% See also: FEM_Preprocessor_v2, FEM_Solver
    % CURVE8ELEMENT: Stateless mathematical engine
    properties
        Coords, Normals, Thickness, E, nu
        per_5=blkdiag(speye(3),[0 1;1 0])
        T_cached    % Cached hybrid transformation matrix (48x48)
        
        % Stateful Properties (Phase 10 Consolidation)
        MaterialModel % Instance of Material (e.g., J2Plastic)
        HistoryData   % Array of structs for GP history
    end

    methods
        function obj = Curve8Element(coords, normals, t, E, nu, matModel, history)
            obj.Coords = coords;
            obj.Normals = normals;
            obj.Thickness = t;
            obj.E = E;
            obj.nu = nu;
            obj.T_cached = obj.Trans_T();
            
            % Initialize state if provided
            if nargin >= 6, obj.MaterialModel = matModel; end
            if nargin >= 7, obj.HistoryData = history; end
        end
    end

    methods(Static)
        [N, dN_dxi, dN_deta] = getShapeFunctions( xi, eta)
        [fun,der] = fmisoq8(xi,eta)
        
    end
    methods
        [D_mb, D_s] = getConstitutiveMatrix(obj)
        Ke = computeStiffnessMatrix(obj)
        Kg = computeGeometricStiffness(obj, u_elem)
        stresses = computeStresses(obj, u_elem)
        [Bm,Bb,detJ]=formBmb(obj,xi,eta)
        [Bs,detJ]=formBs(obj,xi,eta)
        [detJ, dNd_local, theta, N] = calculateKinematics(obj, xi, eta)
        T_hybrid=Trans_T(obj)
        function p = per_5_blkdiag(obj)
            p = blkdiag(obj.per_5, obj.per_5, obj.per_5, obj.per_5, ...
                        obj.per_5, obj.per_5, obj.per_5, obj.per_5);
        end
    end
    methods (Access=protected)
        [KT, F_int, NewHist] = computeTangentStiffnessAndForce(obj, u_elem)
    end

end
