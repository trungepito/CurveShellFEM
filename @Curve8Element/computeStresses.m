%% ---------------------------------------------------------
%  NEW METHOD: Calculate Stress and Strain at Element Center
%  ---------------------------------------------------------
function results = computeStresses(obj, u_elem)
% u_elem: 40x1 vector of element displacements

% We calculate stress at the centroid (xi=0, eta=0)
% for simplicity in averaging.
xi = 0; eta = 0;

% Get Shape functions and B-matrices
[N, dN_dxi, dN_deta] = obj.getShapeFunctions(xi, eta);
[D_mb, D_s] = obj.getConstitutiveMatrix();

% 1. Reconstruct Jacobian and Local Frame (Copy logic from Stiffness)
J_vec = [0,0,0; 0,0,0];
V3_int  = zeros(1,3);
for n = 1:8
    J_vec(1,:) = J_vec(1,:) + dN_dxi(n) * obj.NodeCoords(n,:);
    J_vec(2,:) = J_vec(2,:) + dN_deta(n) * obj.NodeCoords(n,:);
    V3_int  = V3_int  + N(n) * obj.NodeNormals(n,:);
end
V3_int = V3_int / norm(V3_int);
v1 = J_vec(1,:) / norm(J_vec(1,:));
v3 = V3_int;
v2 = cross(v3, v1); v2 = v2/norm(v2);
v1 = cross(v2, v3);
theta = [v1; v2; v3];

% Local Jacobian
J_glob_surf = J_vec;
J_loc = zeros(2,2);
J_loc(1,1) = dot(J_glob_surf(1,:), v1);
J_loc(1,2) = dot(J_glob_surf(1,:), v2);
J_loc(2,1) = dot(J_glob_surf(2,:), v1);
J_loc(2,2) = dot(J_glob_surf(2,:), v2);
invJ = inv(J_loc);
dNd_local = invJ * [dN_dxi; dN_deta];

% 2. Rebuild B-Matrices (Membrane, Bending, Shear)
Bm = zeros(3, 40); Bb = zeros(3, 40); Bs = zeros(2, 40);
T_mat = theta;

for n = 1:8
    idx = (n-1)*5 + (1:5);
    V3_n = obj.NodeNormals(n,:);
    if abs(dot(V3_n, [0,1,0])) < 0.9, v1_n = cross([0,1,0], V3_n);
    else, v1_n = cross([1,0,0], V3_n); end
    v1_n = v1_n / norm(v1_n);
    v2_n = cross(V3_n, v1_n);
    t1 = theta * v1_n'; t2 = theta * v2_n';

    dN_dx = dNd_local(1, n); dN_dy = dNd_local(2, n);

    % Membrane
    Bm(1, idx(1:3)) = dN_dx * T_mat(1,:);
    Bm(2, idx(1:3)) = dN_dy * T_mat(2,:);
    Bm(3, idx(1:3)) = dN_dy * T_mat(1,:) + dN_dx * T_mat(2,:);

    % Bending
    P = -t2; Q = t1;
    Bb(1, idx(4:5)) = [dN_dx*P(1), dN_dx*Q(1)];
    Bb(2, idx(4:5)) = [dN_dy*P(2), dN_dy*Q(2)];
    Bb(3, idx(4:5)) = [dN_dy*P(1)+dN_dx*P(2), dN_dy*Q(1)+dN_dx*Q(2)];

    % Shear
    Bs(1, idx(1:3)) = dN_dx * T_mat(3,:);
    Bs(2, idx(1:3)) = dN_dy * T_mat(3,:);
    Bs(1, idx(4:5)) = Bs(1, idx(4:5)) + N(n)*[P(1), Q(1)]; % Shear correction
    Bs(2, idx(4:5)) = Bs(2, idx(4:5)) + N(n)*[P(2), Q(2)];
end

% 3. Compute Strains
eps_m = Bm * u_elem; % [ex, ey, gxy]
kappa = Bb * u_elem; % [kx, ky, kxy]
gamma = Bs * u_elem; % [gyz, gxz]

h = obj.Thickness;
z_layers = [-h/2, 0, h/2]; % Bottom, Mid, Top

results = struct();
results.vonMises = zeros(3,1);
results.sigma_x  = zeros(3,1);

% Shear Stress (Transverse) is parabolic, max at mid, 0 at surf
% Simplified: Average shear stress
tau_trans = D_s * gamma;

for i = 1:3
    z = z_layers(i);
    % Plane Stress at layer z
    eps_total = eps_m + z * kappa;
    sigma_plane = D_mb(1:3, 1:3) * eps_total; % D_mb is scaled factor, extract 3x3

    % Unpack
    sig_x = sigma_plane(1);
    sig_y = sigma_plane(2);
    tau_xy = sigma_plane(3);

    % Transverse shear (simplify as constant for Von Mises est)
    tau_yz = tau_trans(1);
    tau_xz = tau_trans(2);

    % Store
    results.sigma_x(i) = sig_x;

    % Von Mises
    vm = sqrt(sig_x^2 + sig_y^2 - sig_x*sig_y + 3*(tau_xy^2 + tau_yz^2 + tau_xz^2));
    results.vonMises(i) = vm;
end

% Store Membrane forces for Buckling (Nx, Ny, Nxy) = sigma_mid * h
sigma_mid = D_mb(1:3,1:3) * eps_m;
results.MembraneForces = sigma_mid * h;
end
