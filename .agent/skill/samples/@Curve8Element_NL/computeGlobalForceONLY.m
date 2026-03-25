
function F_int = computeGlobalForceONLY(obj,u_el)
% Computes the 48x1 GLOBAL internal force onnly for line-search
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
F_int = obj.computeintForce(u_el);
% 2. Initialize Expanded 48x48 Matrix (Local Orthogonal Basis)
%    Basis: [U_g, V_g, W_g, Rot_v1, Rot_v2, Rot_v3]
F_out=zeros(48,1);
% Drilling Stabilization Parameter
% Small stiffness to prevent free spinning around the normal

% Permuatataion matrix
F_int=per_40*F_int;
for i = 1:8
    % Indices in 40x40 Mixed Matrix
    r_mix = (i-1)*5 + (1:5);
    % Indices in 48x48 Expanded Matrix
    r_exp = (i-1)*6 + (1:6);
    F_out(r_exp(1:5)) = F_int(r_mix);
end
% 6. Compute Internal Forces
F_int = T_hybrid' * F_out;
end
