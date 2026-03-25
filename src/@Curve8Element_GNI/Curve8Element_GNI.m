classdef Curve8Element_GNI < Curve8Element
% CURVE8ELEMENT_GNI - Geometric Nonlinear Incremental element for large displacements/small strains.
%
% Inherits from Curve8Element, overrides computeTangentStiffnessAndForce for GNI analysis.
% No material plasticity or history variables.
%
% Usage:
%   el = Curve8Element_GNI(coords, normals, t, E, nu)
%
% See also: Curve8Element, FEM_Solver_NL
    methods
        function obj = Curve8Element_GNI(coords, normals, t, E, nu)
            obj@Curve8Element(coords, normals, t, E, nu);
        end
    end

    methods(Access=protected)
        [KT, F_int, NewHist] = computeTangentStiffnessAndForce(obj, u_elem)
    end
end