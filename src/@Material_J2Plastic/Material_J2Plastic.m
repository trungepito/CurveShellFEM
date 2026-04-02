classdef Material_J2Plastic
% MATERIAL_J2PLASTIC - J2 Plasticity (Von Mises) with Isotropic Hardening.
%
% Rigorous Plane Stress formulation with Exact Algorithmic Tangent.

    properties
        E, nu, YieldStress, H
    end
    
    methods
        function obj = Material_J2Plastic(E, nu, sigY, H)
            obj.E = E; obj.nu = nu;
            obj.YieldStress = sigY;
            obj.H = H;
        end
        
        function [sigma_new, Dep, eps_p_new, p_new] = integrateStress(obj, eps_total, eps_p_old, p_old)
            % 1. Local Elastic Matrix
            fac = obj.E / (1 - obj.nu^2);
            D_el = fac * [1, obj.nu, 0; obj.nu, 1, 0; 0, 0, (1-obj.nu)/2];
            
            % 2. Trial Stress
            sigma_trial = D_el * (eps_total - eps_p_old);
            
            sx = sigma_trial(1); sy = sigma_trial(2); txy = sigma_trial(3);
            vm_trial = sqrt(sx^2 + sy^2 - sx*sy + 3*txy^2);
            sig_y_curr = obj.YieldStress + obj.H * p_old;
            
            if vm_trial - sig_y_curr <= 1e-6 * obj.YieldStress
                % ELASTIC
                sigma_new = sigma_trial;
                Dep = D_el;
                eps_p_new = eps_p_old;
                p_new = p_old;
            else
                % PLASTIC (Newton Loop for dG = Delta Gamma)
                P = [1, -0.5, 0; -0.5, 1, 0; 0, 0, 3];
                dG = 0;
                phi = 1; % Init
                for iter = 1:50 % Increased iterations
                    M = eye(3) + dG * D_el * P;
                    % Solved iteratively for robustness
                    sigma_curr = M \ sigma_trial;
                    
                    sx = sigma_curr(1); sy = sigma_curr(2); txy = sigma_curr(3);
                    vm_curr = sqrt(sx^2 + sy^2 - sx*sy + 3*txy^2);
                    
                    phi = vm_curr - (obj.YieldStress + obj.H * (p_old + dG));
                    
                    if abs(phi) < 1e-8 * obj.YieldStress, break; end
                    
                    % Exact derivative
                    n_curr = (1/vm_curr) * [sx - 0.5*sy; sy - 0.5*sx; 3*txy];
                    d_sig_d_dg = - (M \ (D_el * P * sigma_curr));
                    dphi = n_curr' * d_sig_d_dg - obj.H;
                    
                    dG_step = - phi / dphi;
                    % Line search / damping to prevent oscillation
                    dG = dG + 0.8 * dG_step; 
                end
                
                if iter == 50
                    warning('Local J2 loop failed to converge (phi = %.2e)', phi);
                end
                
                sigma_new = sigma_curr;
                p_new = p_old + dG;
                eps_p_new = eps_p_old + dG * n_curr;
                
                % --- EXACT ALGORITHMIC TANGENT (Dep) ---
                Dr = (M \ D_el); 
                denom = n_curr' * Dr * n_curr + obj.H;
                Dep = Dr - (Dr * (n_curr * n_curr') * Dr) / denom;
            end
        end
    end
end