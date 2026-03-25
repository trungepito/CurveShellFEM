function [Bm,Bb,detJ]=formBmb(obj,xi,eta)
% CALCULATE the B matrix at the given point (xi,eta) in the curvilinear
% system
[detJ, dNd_local, theta, N] = obj.calculateKinematics(xi, eta);

% 2. Rebuild B-Matrices (Membrane, Bending, Shear)
Bm = zeros(3, 40); Bb = zeros(3, 40);
T_mat = theta;

for n = 1:8
    idx = (n-1)*5 + (1:5);
    dN_dx = dNd_local(1, n); dN_dy = dNd_local(2, n);
    V3 = obj.Normals(n,:); V3=V3/norm(V3);
    if abs(V3(2)) < 0.9, V1=cross([0,1,0],V3); else, V1=cross([1,0,0],V3); end
    V1=V1/norm(V1); V2=cross(V3,V1);
    % Membrane
    Bm(1, idx(1:3)) = dN_dx * T_mat(1,:);
    Bm(2, idx(1:3)) = dN_dy * T_mat(2,:);
    Bm(3, idx(1:3)) = dN_dy * T_mat(1,:) + dN_dx * T_mat(2,:);

    % Bending
    P = theta*V1'; Q = -theta*V2';
    Bb(1, idx(4:5)) = [dN_dx*P(1), dN_dx*Q(1)];
    Bb(2, idx(4:5)) = [dN_dy*P(2), dN_dy*Q(2)];
    Bb(3, idx(4:5)) = [dN_dy*P(1)+dN_dx*P(2), dN_dy*Q(1)+dN_dx*Q(2)];

    % Shear
end

end