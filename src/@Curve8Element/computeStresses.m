%% ---------------------------------------------------------
%  NEW METHOD: Calculate Stress and Strain at Element Center
%  ---------------------------------------------------------
function results = computeStresses(obj, u_elem)
% u_elem: 40x1 vector of element displacements

% We calculate stress at the centroid (xi=0, eta=0)
% for simplicity in averaging.
xi = 0; eta = 0;

% Get Shape functions and B-matrices
% [N, der] = obj.fmisoq8(xi, eta);
[D_mb, D_s] = obj.getConstitutiveMatrix();
[Bm,Bb,~]=obj.formBmb(xi,eta);
[Bs,~]=obj.formBs(xi,eta);
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
