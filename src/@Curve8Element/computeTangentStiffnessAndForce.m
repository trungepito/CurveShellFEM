function [KT, F_int, NewHistory] = computeTangentStiffnessAndForce(obj, u_elem)
% COMPUTETANGENTSTIFFNESSANDFORCE - Unified Tangent Stiffness (Phase 10).
%
% This method handles linear or nonlinear materials based on obj.MaterialModel.

    KT = zeros(40, 40);
    F_int = zeros(40, 1);
    NewHistory = obj.HistoryData; 
    
    h = obj.Thickness;
    [D_el, D_s] = obj.getConstitutiveMatrix();
    
    % Integration Scheme: 2x2 Gauss x 5 Simpson/Zeta
    sqrt3_inv = 1/sqrt(3);
    g_pts = [-sqrt3_inv, sqrt3_inv];
    g_wts = [1.0, 1.0];
    
    zeta_pts = [-1, -0.5, 0, 0.5, 1];
    zeta_wts = [1, 4, 2, 4, 1] / 6; 
    
    pt_counter = 0;
    
    for i = 1:2
        for j = 1:2
            xi = g_pts(i); eta = g_pts(j);
            w_area = g_wts(i) * g_wts(j);
            
            [detJ, dNd_local, ~, ~] = obj.calculateKinematics(xi, eta);
            [Bm0, Bb0] = obj.formBmb(xi, eta);
            [Bs0, ~] = obj.formBs(xi, eta);
            
            G = zeros(2, 40);
            for n = 1:8
                G(1, (n-1)*5 + 1) = dNd_local(1, n);
                G(2, (n-1)*5 + 2) = dNd_local(2, n);
            end
            theta_k = G * u_elem; 
            
            A_geom = [theta_k(1), 0; 0, theta_k(2); theta_k(2), theta_k(1)];
            eps_m = Bm0 * u_elem + 0.5 * A_geom * theta_k;
            kappa = Bb0 * u_elem;
            gamma = Bs0 * u_elem;
            
            Bm_total = Bm0 + A_geom * G;
            
            A_mat = zeros(3,3); B_mat = zeros(3,3); D_mat = zeros(3,3);
            Res_N = zeros(3,1); Res_M = zeros(3,1);
            
            for k = 1:5
                zeta = zeta_pts(k);
                w_thick = zeta_wts(k) * h; 
                z_phys = zeta * h / 2;
                pt_counter = pt_counter + 1;
                
                % Current Total Strain
                eps_total = eps_m + z_phys * kappa;
                
                if ~isempty(obj.MaterialModel)
                    % Nonlinear Integration (Plasticity)
                    eps_p_old = obj.HistoryData(pt_counter).eps_p;
                    p_old = obj.HistoryData(pt_counter).p;
                    
                    [sig_new, Dep_new, eps_p_new, p_new] = ...
                        obj.MaterialModel.integrateStress(eps_total, eps_p_old, p_old);
                    
                    NewHistory(pt_counter).sigma = sig_new;
                    NewHistory(pt_counter).eps_p = eps_p_new;
                    NewHistory(pt_counter).p = p_new;
                else
                    % Linear Elastic Fallback
                    sig_new = D_el * eps_total;
                    Dep_new = D_el;
                end
                
                Res_N = Res_N + sig_new * w_thick;
                Res_M = Res_M + sig_new * z_phys * w_thick;
                
                A_mat = A_mat + Dep_new * w_thick;
                B_mat = B_mat + Dep_new * z_phys * w_thick;
                D_mat = D_mat + Dep_new * (z_phys^2) * w_thick;
            end
            
            k_s = 5/6; % Shear Correction
            Q_res = D_s * gamma * h * k_s;
            Ks_contrib = Bs0' * (D_s * h * k_s) * Bs0;
            
            fe = (Bm_total' * Res_N + Bb0' * Res_M + Bs0' * Q_res) * detJ * w_area;
            F_int = F_int + fe;
            
            Ke_mat = (Bm_total' * A_mat * Bm_total + Bm_total' * B_mat * Bb0 + ...
                      Bb0' * B_mat * Bm_total + Bb0' * D_mat * Bb0 + Ks_contrib) * detJ * w_area;
                      
            S_mtx = [Res_N(1), Res_N(3); Res_N(3), Res_N(2)];
            Ke_geo = (G' * S_mtx * G) * detJ * w_area;
            
            KT = KT + (Ke_mat + Ke_geo);
        end
    end
end