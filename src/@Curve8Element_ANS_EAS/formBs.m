function [Bs_ans, detJ] = formBs(obj, xi, eta)
% formBs: Overridden for ANS (Assumed Natural Strain) Transverse Shear.
% Samples shear at tied points (A, B, C, D) to prevent locking.

% 1. Sample shear Bs at Bathe-Dvorkin points
% Point A (0, 1), B (0, -1) for gam_xi_z
% Point C (1, 0), D (-1, 0) for gam_eta_z

[BsA, detJA] = obj.formBs_at(0, 1);
[BsB, detJB] = obj.formBs_at(0,-1);
[BsC, detJC] = obj.formBs_at(1, 0);
[BsD, detJD] = obj.formBs_at(-1,0);

% 2. Get standard Bs at current (xi, eta) to get Jacobian/DetJ
[Bs_std, detJ] = obj.formBs_at(xi, eta);

% 3. Interpolate ANS Shear Components
% gamma_xi_z is row 1 of Bs
% gamma_eta_z is row 2 of Bs
Bs_ans = zeros(2, 40);

% Linear interpolation for ANS components
Bs_ans(1, :) = 0.5 * (1 + eta) * BsA(1, :) + 0.5 * (1 - eta) * BsB(1, :);
Bs_ans(2, :) = 0.5 * (1 + xi)  * BsC(2, :) + 0.5 * (1 - xi)  * BsD(2, :);

end
