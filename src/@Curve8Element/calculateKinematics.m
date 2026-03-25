function [detJ, dNd_local, theta, N] = calculateKinematics(obj, xi, eta)
% CALCULATEKINEMATICS Shared geometric calculations for 8-node curved shell
% Inputs: xi, eta (Gauss point coordinates)
% Outputs: 
%   detJ      - Determinant of the local Jacobian
%   dNd_local - Shape function derivatives in local frame (2x8)
%   theta     - Transformation matrix [v1; v2; v3] (3x3)
%   N         - Shape functions at (xi, eta) (1x8)

% 1. Evaluate shape functions and global derivatives
[N, der] = obj.fmisoq8(xi, eta);

% 2. Reconstruct Local Frame (theta)
% V3 is the interpolated normal, V1 follows the surface xi-direction
V3_int = N * obj.Normals;
J_vec  = der * obj.Coords; % [dx/dxi dy/dxi dz/dxi; dx/deta dy/deta dz/deta]

V3_int = V3_int / norm(V3_int);
v1 = J_vec(1,:) / norm(J_vec(1,:));
v3 = V3_int;
v2 = cross(v3, v1); v2 = v2 / norm(v2);
v1 = cross(v2, v3); % Ensure orthogonality
theta = [v1; v2; v3];

% 3. Project Global Jacobian to Local Frame
% We need the 2x2 Jacobian in the tangent plane for detJ and invJ
J_loc = zeros(2, 2);
J_loc(1,1) = dot(J_vec(1,:), v1);
J_loc(1,2) = dot(J_vec(1,:), v2);
J_loc(2,1) = dot(J_vec(2,:), v1);
J_loc(2,2) = dot(J_vec(2,:), v2);

detJ = det(J_loc);
invJ = J_loc \ eye(2);

% 4. Transform Derivatives to Local Frame
dNd_local = invJ * der;

end
