%% Diagnostic: EAS Condensation Health Check
% Checks whether K_aa is well-conditioned and whether condensation
% reduces or increases the stiffness appropriately.

clear; clc; addpath(genpath('.'));

% Flat square element
coords = [0,0,0; 1,0,0; 1,1,0; 0,1,0; 0.5,0,0; 1,0.5,0; 0.5,1,0; 0,0.5,0];
normals = repmat([0,0,1], 8, 1);
t = 0.1; E = 210e3; nu = 0.3;

% Manually replicate the condensation to inspect K_aa
nGauss = 3; nLayer = 5;
[gp_s, gw_s] = MathFEM.Gauss_p(nGauss);
[gp_z, gw_z] = MathFEM.Gauss_p(nLayer);

el  = Curve8Element_ANS_EAS(coords, normals, t, E, nu);
[D_mb, ~] = el.getConstitutiveMatrix();

Ke_uu = zeros(40,40);
Ke_ua = zeros(40,4);
Ke_aa = zeros(4,4);

for i = 1:nGauss
  for j = 1:nGauss
    xi = gp_s(i); eta = gp_s(j);
    [Bm, Bb, detJ] = el.formBmb(xi, eta);
    M = el.formM(xi, eta);
    w = gw_s(i) * gw_s(j);
    for k = 1:nLayer
      z = gp_z(k);
      wz = gw_z(k) * (t/2);
      dV = detJ * w * wz;
      B = Bm + z*Bb;
      Ke_uu = Ke_uu + B' * D_mb * B * dV;
      Ke_ua = Ke_ua + B' * D_mb * M(1:3,:) * dV;
      Ke_aa = Ke_aa + M(1:3,:)' * D_mb * M(1:3,:) * dV;
    end
  end
end

fprintf('K_aa condition number:     %.3e\n', cond(Ke_aa));
fprintf('K_aa min eigenvalue:       %.3e\n', min(eig(Ke_aa)));
fprintf('K_ua norm:                 %.3e\n', norm(Ke_ua,'fro'));

Ke_cond = Ke_uu - Ke_ua * (Ke_aa \ Ke_ua');
ev_raw  = sort(abs(eig(Ke_uu)));
ev_cond = sort(abs(eig(Ke_cond)));
fprintf('Raw   max eigenvalue: %.3e\n', ev_raw(end));
fprintf('Cond  max eigenvalue: %.3e\n', ev_cond(end));
fprintf('Condensation reduces stiffness? %s\n', char(string(ev_cond(end) < ev_raw(end))));
