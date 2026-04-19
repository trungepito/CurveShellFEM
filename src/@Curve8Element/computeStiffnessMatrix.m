function Ke = computeStiffnessMatrix(obj)
Ke = zeros(40, 40); % 8 nodes * 5 DOFs

% Gaussian Quadrature
% 3x3 rule is recommended for 8-node elements to prevent hour-glassing
% though 2x2 is sometimes used for shear to prevent locking.
% Here we use 3x3 for simplicity
[D_mb, D_s] = obj.getConstitutiveMatrix();
Gpoint_mb=2;% number of gauss points for Membrane and Bending term
Gpoint_s=2; % number of gauss points for Shear term

% Membrane and Bending term integration
[g_points, g_weights] = MathFEM.Gauss_p(Gpoint_mb);
[gp_xi, gp_eta] = meshgrid(g_points, g_points);
gp_w = g_weights(:) * g_weights(:)';
gp_w = gp_w(:);
% Vectorized B-matrix call for all points at once
[Bm_all, Bb_all, detJ_all] = obj.formBmb(gp_xi(:), gp_eta(:));

h = obj.Thickness;
h3_12 = (h^3 / 12);

for k = 1:length(gp_w)
    Bm = Bm_all(:,:,k); Bb = Bb_all(:,:,k);
    Ke = Ke + (Bm' * D_mb * Bm * h + Bb' * D_mb * Bb * h3_12) * (detJ_all(k) * gp_w(k));
end

% Shear term integration
[g_points, g_weights] = MathFEM.Gauss_p(Gpoint_s);
[gp_xi, gp_eta] = meshgrid(g_points, g_points);
gp_w = g_weights(:) * g_weights(:)';
gp_w = gp_w(:);
[Bs_all, detJ_s] = obj.formBs(gp_xi(:), gp_eta(:));

for k = 1:length(gp_w)
    Bs = Bs_all(:,:,k);
    Ke = Ke + (Bs' * D_s * Bs * h) * (detJ_s(k) * gp_w(k));
end

end

