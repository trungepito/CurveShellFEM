function Ke = computeStiffnessMatrix(obj)
% computeStiffnessMatrix: ANS/EAS with correct split integration.
%
% Key design decisions:
%   - Membrane/Bending + EAS: 3x3 Gauss (full integration, no locking because EAS handles it)
%   - Transverse Shear (ANS): 2x2 Gauss (consistent with baseline; ANS tying handles locking)

Ke_uu = zeros(40, 40);
Ke_ua = zeros(40, 4);
Ke_aa = zeros(4, 4);

[D_mb, D_s] = obj.getConstitutiveMatrix();
k_shear = 5/6;

% -----------------------------------------------------------
% Part 1: Transverse Shear - 2x2 Gauss (ANS-interpolated Bs)
% -----------------------------------------------------------
[gp2, gw2] = MathFEM.Gauss_p(2);
for i = 1:2
    for j = 1:2
        [Bs, detJ_s] = obj.formBs(gp2(i), gp2(j));   % overridden ANS formBs
        dA = detJ_s * gw2(i) * gw2(j);
        Ke_uu = Ke_uu + Bs' * (D_s * obj.Thickness * k_shear) * Bs * dA;
    end
end

% -----------------------------------------------------------
% Part 2: Membrane + Bending + EAS - 3x3 Gauss x 5 layers
% -----------------------------------------------------------
nLayer = 5;
[gp3, gw3] = MathFEM.Gauss_p(3);
[gp_z, gw_z] = MathFEM.Gauss_p(nLayer);

for i = 1:3
    for j = 1:3
        xi = gp3(i); eta = gp3(j);
        [Bm, Bb, detJ_m] = obj.formBmb(xi, eta);
        M = obj.formM(xi, eta);   % 4-parameter EAS basis
        w_surf = gw3(i) * gw3(j);

        for k = 1:nLayer
            z   = gp_z(k);
            w_z = gw_z(k) * (obj.Thickness / 2);
            dV  = detJ_m * w_surf * w_z;

            B_comp = Bm + z * Bb;

            Ke_uu = Ke_uu + B_comp' * D_mb * B_comp * dV;
            Ke_ua = Ke_ua + B_comp' * D_mb * M(1:3,:) * dV;
            Ke_aa = Ke_aa + M(1:3,:)' * D_mb * M(1:3,:) * dV;
        end
    end
end

% -----------------------------------------------------------
% Part 3: Static Condensation of EAS internal DOFs
% -----------------------------------------------------------
Ke = Ke_uu - Ke_ua * (Ke_aa \ Ke_ua');

end
