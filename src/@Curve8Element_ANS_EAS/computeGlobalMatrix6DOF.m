function [Ke_global, fe_global, NewHist] = computeGlobalMatrix6DOF(obj, u_el)
% computeGlobalMatrix6DOF: Overridden for Curve8Element_ANS_EAS.

T_hybrid = obj.T_cached;

if nargin < 2 || isempty(u_el)
    % Linear Stiffness Only
    Ke_mixed = obj.computeStiffnessMatrix();
    fe_mixed = zeros(40, 1);
    NewHist = obj.HistoryData;
else
    % Full Tangent and Internal Force
    [Ke_mixed, fe_mixed, NewHist] = obj.computeTangentStiffnessAndForce(u_el);
end

% Expand 40-DOF mixed basis to 48-DOF global basis
Ke_exp = zeros(48, 48);
fe_exp = zeros(48, 1);

% Block-diagonal expansion (indices 1:5 of each node)
for i = 1:8
    r_mix_i = (i-1)*5 + (1:5);
    r_exp_i = (i-1)*6 + (1:6);
    
    fe_exp(r_exp_i(1:5)) = fe_mixed(r_mix_i);
    
    for j = 1:8
        r_mix_j = (j-1)*5 + (1:5);
        r_exp_j = (j-1)*6 + (1:6);
        Ke_exp(r_exp_i(1:5), r_exp_j(1:5)) = Ke_mixed(r_mix_i, r_mix_j);
    end
end

% Add drilling stabilization (drilling DOF is the 6th DOF in local basis)
% Use mean of absolute diagonal values of the mixed-basis part for scaling
avg_diag = mean(abs(diag(Ke_exp(1:48, 1:48)))); 
k_drill = 1e-4 * avg_diag;
for i = 1:8
    r_exp_i = (i-1)*6 + (1:6);
    Ke_exp(r_exp_i(6), r_exp_i(6)) = k_drill;
end

% Transform to Global Coordinates
Ke_global = T_hybrid' * Ke_exp * T_hybrid;
fe_global = T_hybrid' * fe_exp;

end
