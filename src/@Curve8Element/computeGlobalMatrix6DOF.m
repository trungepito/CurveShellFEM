function [Ke_global, fe_global, NewHist] = computeGlobalMatrix6DOF(obj, u_el)
% [Ke_global, fe_global, NewHist] = computeGlobalMatrix6DOF(obj, u_el)
% Unified 48-DOF Tangent Stiffness, Internal Force, and History calculation.

T_hybrid = obj.T_cached;
Ke_global = zeros(48, 48);
fe_global = zeros(48, 1);
NewHist = []; % Default for elastic

% 1. Map Global DOFs (48) to Mixed Basis (40)
if nargin < 2 || isempty(u_el)
    % LINEAR MODE: Return Elastic Stiffness and Zero Force
    Ke_mixed = obj.computeStiffnessMatrix();
    % [Ke_mixed, ~, ~] = obj.computeTangentStiffnessAndForce(zeros(40,1));
    % the unify concept, need to be check
    fe_mixed = zeros(40, 1);
else
    % NONLINEAR MODE: Compute Tangent (Ke + Kg) and Internal Force
    u_el_l = T_hybrid * u_el;
    
    % Strip drilling components and permute to mixed basis [u,v,w,alpha,beta]
    % (Keeping existing index-stripping logic for 48->40 mapping)
    u_el_stripped = u_el_l;
    u_el_stripped(6:6:end) = []; 
    u_mix = obj.per_5_blkdiag() * u_el_stripped;
    
    % Unified call (Phase 10)
    [Ke_mixed, fe_mixed, NewHist] = obj.computeTangentStiffnessAndForce(u_mix);
end

% 2. Map Mixed Basis (40) back to Expanded Basis (48)
% Mixed: [u, v, w, alpha, beta] per node
% Expanded: [u, v, w, Rv1, Rv2, Wz] per node
avg_diag = mean(diag(Ke_mixed));
k_drill = 1e-4 * avg_diag; 

% Permute Mixed Basis to match Expanded (swapping alpha/beta)
Ke_out = obj.per_5_blkdiag() * Ke_mixed * obj.per_5_blkdiag();
fe_out = obj.per_5_blkdiag() * fe_mixed;

Ke_exp = zeros(48, 48);
fe_exp = zeros(48, 1);

% Map ALL nodes to ALL nodes
for i = 1:8
    r_mix_i = (i-1)*5 + (1:5);
    r_exp_i = (i-1)*6 + (1:6);
    
    fe_exp(r_exp_i(1:5)) = fe_out(r_mix_i);
    Ke_exp(r_exp_i(6), r_exp_i(6)) = k_drill; % Drilling Stabilization
    
    for j = 1:8
        r_mix_j = (j-1)*5 + (1:5);
        r_exp_j = (j-1)*6 + (1:6);
        
        Ke_exp(r_exp_i(1:5), r_exp_j(1:5)) = Ke_out(r_mix_i, r_mix_j);
    end
end

% 3. Transform to Global Coordinates
Ke_global = T_hybrid' * Ke_exp * T_hybrid;
fe_global = T_hybrid' * fe_exp;

end
