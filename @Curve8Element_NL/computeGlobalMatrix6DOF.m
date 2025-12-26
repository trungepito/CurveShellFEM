
function [KT_glob,F_int] = computeGlobalMatrix6DOF(obj,u_el)
% Computes the 48x48 Element Stiffness Matrix in Global Coordinates
% Input: u_global_6dof (48x1 vector, optional, for nonlinear force calc)
% 1. Compute the Standard 40x40 Stiffness (Mixed Basis)
%    [U_glob, V_glob, W_glob, alpha_loc, beta_loc]
%    (This uses your existing computeStiffnessMatrix logic)

% Transform the global u to standard u_mixed
T_hybrid = obj.Trans_T();
u_el_l=T_hybrid*u_el;
u_el_l(6:6:end)=[];
per_40=kron(eye(8), obj.per_5);
u_el=per_40*u_el_l;

[KT,F_int] = obj.computeTangentStiffnessAndForce(u_el);
avg_diag = mean(diag(KT));
k_drill = 10e-3*avg_diag;
% 2. Initialize Expanded 48x48 Matrix (Local Orthogonal Basis)
%    Basis: [U_g, V_g, W_g, Rot_v1, Rot_v2, Rot_v3]
Ke_exp = zeros(48, 48);
F_out=zeros(48,1);
% Drilling Stabilization Parameter
% Small stiffness to prevent free spinning around the normal

% Permuatataion matrix
Ke_out=per_40*KT*per_40;
F_int=per_40*F_int;
for i = 1:8
    for j = 1:8
        % Indices in 40x40 Mixed Matrix
        r_mix = (i-1)*5 + (1:5);
        c_mix = (j-1)*5 + (1:5);
        % Indices in 48x48 Expanded Matrix
        r_exp = (i-1)*6 + (1:6);
        c_exp = (j-1)*6 + (1:6);
        % Extract Block
        Ke_exp(r_exp(1:5), c_exp(1:5)) = Ke_out(r_mix, c_mix);
    end
    % Add Drilling Stiffness (Diagonal only)
    d_idx = (i-1)*6 + 6;
    F_out(r_exp(1:5)) = F_int(r_mix);
    Ke_exp(d_idx, d_idx) = k_drill;
end

% 4. Construct Hybrid Transformation Matrix (T_hybrid)
%    Maps Global DOFs [U,V,W, Tx,Ty,Tz] to [U,V,W, Rv1, Rv2, Rv3]
% 5. Transform
% K_global = T' * K_expanded * T
KT_glob = T_hybrid' * Ke_exp * T_hybrid;
% 6. Compute Internal Forces
F_int = T_hybrid' * F_out;
end
