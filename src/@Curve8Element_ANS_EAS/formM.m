function M = formM(obj, xi, eta)
% formM: EAS enhancement basis functions (4-parameter stable)
% nh-strains order: [eps_xi, eps_eta, gam_xi_eta, gam_xi_z, gam_eta_z]

% Get Jacobian at center for scaling (ensure Patch Test)
[detJ0, ~, ~, ~] = obj.calculateKinematics(0, 0);
[detJ, ~, ~, ~] = obj.calculateKinematics(xi, eta);

scale = detJ0 / detJ;

M = zeros(5, 4);

% Membrane enhancement (Standard 4-parameter Simo-Rifai)
M(1, 1) = xi * scale;
M(2, 2) = eta * scale;
M(3, 3) = xi * scale;
M(3, 4) = eta * scale;

end
