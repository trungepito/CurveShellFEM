function [Bs, detJ] = formBs_at(obj, xi, eta)
% formBs_at: Helper for ANS to sample standard Bs at specific points.
% Synchronized with baseline Curve8Element/formBs.m logic.

[detJ, dNd_local, theta, N] = obj.calculateKinematics(xi, eta);
Bs = zeros(2, 40);

for n = 1:8
    idx = (n-1)*5 + (1:5);
    dN_dx = dNd_local(1, n); 
    dN_dy = dNd_local(2, n);
    
    % Get Node-wise Frame (Baseline Logic)
    V3 = obj.Normals(n,:); V3 = V3/norm(V3);
    if abs(V3(2)) < 0.9, V1=cross([0,1,0],V3); else, V1=cross([1,0,0],V3); end
    V1 = V1/norm(V1); V2 = cross(V3,V1);
    
    % Natural to Cartesian projection vectors
    % P: contribution of alpha rotation to gam_xz
    % Q: contribution of beta rotation to gam_xz
    P = theta * V1'; Q = -theta * V2';
    
    % 1. Transverse Shear (Displacement Part)
    Bs(1, idx(1:3)) = dN_dx * theta(3,:);
    Bs(2, idx(1:3)) = dN_dy * theta(3,:);
    
    % 2. Transverse Shear (Rotation Part) - Corrected Dimensions
    % gamma_xz = ... + N * (alpha*P(1) + beta*Q(1))
    Bs(1, idx(4:5)) = N(n) * [P(1), Q(1)]; 
    Bs(2, idx(4:5)) = N(n) * [P(2), Q(2)];
end
end
