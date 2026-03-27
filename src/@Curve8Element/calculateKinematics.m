function [detJ, dNd_local, theta, N] = calculateKinematics(obj, xi, eta)
% CALCULATEKINEMATICS Shared geometric calculations for 8-node curved shell
% Supports batch Gauss points (xi, eta as vectors).

% 1. Evaluate shape functions and global derivatives
[N, der] = obj.fmisoq8(xi, eta);
nGP = length(xi);

% 2. Reconstruct Local Frame (theta) per point
V3_int = N * obj.Normals; % [nGP x 3]
% J_vec = der * obj.Coords;
% Vectorized J_vec calculation for all points
% J_vec is [2 x 3 x nGP]
J_vec = zeros(2, 3, nGP);
for k = 1:nGP
    J_vec(:,:,k) = der(:,:,k) * obj.Coords;
end

detJ = zeros(nGP, 1);
dNd_local = zeros(2, 8, nGP);
theta = zeros(3, 3, nGP);

for k = 1:nGP
    v3 = V3_int(k,:) / norm(V3_int(k,:));
    J_k = J_vec(:,:,k);
    
    v1 = J_k(1,:) / norm(J_k(1,:));
    v2 = cross(v3, v1); v2 = v2 / norm(v2);
    v1 = cross(v2, v3); % Orthogonalize
    
    th = [v1; v2; v3];
    theta(:,:,k) = th;
    
    % 3. Local Jacobian (2x2)
    J_loc = J_k * th(1:2, :)'; % Transform global J to local plane
    
    detJ(k) = det(J_loc);
    invJ = J_loc \ eye(2);
    
    % 4. Transform Derivatives
    dNd_local(:,:,k) = invJ * der(:,:,k);
end

end
