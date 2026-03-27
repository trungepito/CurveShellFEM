function Kg_global = computeGlobalKg6DOF(obj, u_el)
% computeGlobalKg6DOF: Isolates and transforms Geometric Stiffness to Global 48-DOF.
% Used for Linear Eigenvalue Buckling.

T_hybrid = obj.T_cached;
Kg_global = zeros(48, 48);

% 1. Map Global DOFs (48) to Mixed Basis (40)
u_el_l = T_hybrid * u_el;
u_el_l(6:6:end) = []; % Strip drilling components
u_mix = obj.per_5_blkdiag() * u_el_l;

% 2. Compute 40-DOF Geometric Stiffness
Kg_mixed = obj.computeGeometricStiffness(u_mix);

% 3. Map Mixed Basis (40) back to Expanded Basis (48)
% (No drilling stabilization needed for Kg)
Kg_out = obj.per_5_blkdiag() * Kg_mixed * obj.per_5_blkdiag();

Kg_exp = zeros(48, 48);
for i = 1:8
    r_mix_i = (i-1)*5 + (1:5);
    r_exp_i = (i-1)*6 + (1:6);
    for j = 1:8
        r_mix_j = (j-1)*5 + (1:5);
        r_exp_j = (j-1)*6 + (1:6);
        Kg_exp(r_exp_i(1:5), r_exp_j(1:5)) = Kg_out(r_mix_i, r_mix_j);
    end
end

% 4. Transform to Global Coordinates
Kg_global = T_hybrid' * Kg_exp * T_hybrid;

end
