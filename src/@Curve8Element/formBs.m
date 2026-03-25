function [Bs,detJ]=formBs(obj,xi,eta)
% CALCULATE the B matrix at the given point (xi,eta) in the curvilinear
% system
[detJ, dNd_local, theta, N] = obj.calculateKinematics(xi, eta);

% 2. Rebuild B-Matrices (Membrane, Bending, Shear)
Bs = zeros(2, 40);
for n = 1:8
    idx = (n-1)*5 + (1:5);
    dN_dx = dNd_local(1, n); dN_dy = dNd_local(2, n);
    V3 = obj.Normals(n,:); V3=V3/norm(V3);
    if abs(V3(2)) < 0.9, V1=cross([0,1,0],V3); else, V1=cross([1,0,0],V3); end
    V1=V1/norm(V1); V2=cross(V3,V1);
    % Membrane
    % Bending
    P = theta*V1'; Q = -theta*V2';
    % Shear
    Bs(1, idx(1:3)) = dN_dx * theta(3,:);
    Bs(2, idx(1:3)) = dN_dy * theta(3,:);
    Bs(1, idx(4:5)) = Bs(1, idx(4:5)) + N(n)*[P(1), Q(1)]; % Shear correction
    Bs(2, idx(4:5)) = Bs(2, idx(4:5)) + N(n)*[P(2), Q(2)];
end

end