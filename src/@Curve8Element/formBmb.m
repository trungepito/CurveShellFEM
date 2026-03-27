function [Bm, Bb, detJ] = formBmb(obj, xi, eta)
% FORMBMB - Vectorized B-matrix calculation for Membrane & Bending.
% Supports batch Gauss points.

[detJ, dNd_local, theta_all, ~] = obj.calculateKinematics(xi, eta);
nGP = length(detJ);

Bm = zeros(3, 40, nGP); 
Bb = zeros(3, 40, nGP);

for k = 1:nGP
    dN = dNd_local(:,:,k);
    th = theta_all(:,:,k);
    
    for n = 1:8
        idx = (n-1)*5 + (1:5);
        dN_dx = dN(1, n); dN_dy = dN(2, n);
        
        % V3 is node-based, but theta is GP-based
        V3 = obj.Normals(n,:); V3 = V3/norm(V3);
        if abs(V3(2)) < 0.9, V1=cross([0,1,0],V3); else, V1=cross([1,0,0],V3); end
        V1 = V1/norm(V1); V2 = cross(V3,V1);
        
        % Membrane (Curvilinear projection)
        Bm(1, idx(1:3), k) = dN_dx * th(1,:);
        Bm(2, idx(1:3), k) = dN_dy * th(2,:);
        Bm(3, idx(1:3), k) = dN_dy * th(1,:) + dN_dx * th(2,:);

        % Bending (Curvature terms)
        P = th * V1'; Q = -th * V2';
        Bb(1, idx(4:5), k) = [dN_dx*P(1), dN_dx*Q(1)];
        Bb(2, idx(4:5), k) = [dN_dy*P(2), dN_dy*Q(2)];
        Bb(3, idx(4:5), k) = [dN_dy*P(1)+dN_dx*P(2), dN_dy*Q(1)+dN_dx*Q(2)];
    end
end
end