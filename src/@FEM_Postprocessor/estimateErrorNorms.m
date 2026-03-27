function [error_norm_el, total_error] = estimateErrorNorms(obj)
% ESTIMATEERRORNORMS - Zienkiewicz-Zhu (ZZ) error estimation.
% Calculates element-wise energy norm of error: ||e||^2 = integral( e_sig' * D^-1 * e_sig ) dV

nElems = size(obj.Model.Mesh.Elements, 1);
error_norm_el = zeros(nElems, 1);
total_u_norm = 0; % ||u||^2

% 1. Get smoothed nodal stresses (SPR) for all components
sigX_nodal = obj.recoverNodalStressSPR('SigmaX', 'Mid');
sigY_nodal = obj.recoverNodalStressSPR('SigmaY', 'Mid');
tauXY_nodal = obj.recoverNodalStressSPR('TauXY', 'Mid');

h = obj.Model.Material.t;

% 2. Integration over elements
% Using same GP rule as stiffness for consistency
[g_points, g_weights] = MathFEM.Gauss_p(3);
[gp_xi, gp_eta] = meshgrid(g_points, g_points);
gp_w = g_weights(:) * g_weights(:)';
gp_w = gp_w(:);

for e = 1:nElems
    elObj = obj.Solver.Elements{e};
    u_el = obj.Solver.U(obj.Solver.SctrMap(e, :));
    D_el = elObj.getConstitutiveMatrix();
    invD = inv(D_el(1:3, 1:3));
    
    % Nodal SPR stresses for this element
    nodes_e = obj.Model.Mesh.Elements(e, 1:8);
    s_nodal = [sigX_nodal(nodes_e), sigY_nodal(nodes_e), tauXY_nodal(nodes_e)]; % [8 x 3]
    
    [detJ_all, ~, ~, N_all] = elObj.calculateKinematics(gp_xi(:), gp_eta(:));
    [Bm_all, ~, ~] = elObj.formBmb(gp_xi(:), gp_eta(:));
    
    e_norm_e = 0;
    u_norm_e = 0;
    
    for k = 1:length(gp_w)
        N_k = N_all(k, :);
        
        % Interpolated smoothed stress sigma* [3 x 1]
        sig_star = (N_k * s_nodal)';
        
        % Map Global DOFs (48) to Mixed Basis (40)
        T_hybrid = elObj.T_cached;
        u_el_l = T_hybrid * u_el;
        u_el_l(6:6:end) = []; % Strip drilling
        u_mix = elObj.per_5_blkdiag() * u_el_l;
        
        % Raw solver stress sigma_h
        Bm = Bm_all(:,:,k);
        sig_h = D_el(1:3, 1:3) * (Bm * u_mix);
        
        % Error stress
        e_sig = sig_star - sig_h;
        
        dV = detJ_all(k) * gp_w(k) * h;
        e_norm_e = e_norm_e + (e_sig' * invD * e_sig) * dV;
        u_norm_e = u_norm_e + (sig_h' * invD * sig_h) * dV;
    end
    
    error_norm_el(e) = sqrt(max(0, e_norm_e));
    total_u_norm = total_u_norm + u_norm_e;
end

total_error = sqrt(sum(error_norm_el.^2)) / sqrt(total_u_norm);

fprintf('[SPR/ZZ] Global Error Estimate (Energy Norm): %.2f%%\n', total_error * 100);

end
