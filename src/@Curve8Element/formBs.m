function [Bs, detJ] = formBs(obj, xi, eta)
% FORMBS - Vectorized B-matrix calculation for Transverse Shear.
% Supports batch Gauss points.

[detJ, dNd_local, theta_all, N_all] = obj.calculateKinematics(xi, eta);
nGP = length(detJ);

Bs = zeros(2, 40, nGP);

for k = 1:nGP
    dN = dNd_local(:,:,k);
    th = theta_all(:,:,k);
    N  = N_all(k, :);
    
    for n = 1:8
        idx = (n-1)*5 + (1:5);
        dN_dx = dN(1, n); dN_dy = dN(2, n);
        
        V3 = obj.Normals(n,:); V3 = V3/norm(V3);
        if abs(V3(2)) < 0.9, V1=cross([0,1,0],V3); else, V1=cross([1,0,0],V3); end
        V1 = V1/norm(V1); V2 = cross(V3,V1);
        
        P = th * V1'; Q = -th * V2';
        
        % Shear (Curvilinear projection)
        Bs(1, idx(1:3), k) = dN_dx * th(3,:);
        Bs(2, idx(1:3), k) = dN_dy * th(3,:);
        
        % Shear correction (Director rotations)
        Bs(1, idx(4:5), k) = Bs(1, idx(4:5), k) + N(n) * [P(1), Q(1)];
        Bs(2, idx(4:5), k) = Bs(2, idx(4:5), k) + N(n) * [P(2), Q(2)];
    end
end
end