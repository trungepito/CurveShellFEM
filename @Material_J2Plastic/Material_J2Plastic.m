classdef Material_J2Plastic
    properties
        E, nu, YieldStress, H % H = Hardening Modulus (Et)
    end
    
    methods
        function obj = Material_J2Plastic(E, nu, sigY, H)
            obj.E = E; obj.nu = nu;
            obj.YieldStress = sigY;
            obj.H = H;
        end
        
        function [sigma_new, Dep, eps_p_new] = integrateStress(obj, eps_total_new, eps_p_old, eps_old)
            % Implements Radial Return Mapping for Plane Stress
            
            % 1. Elastic Matrix (Plane Stress)
            fac = obj.E / (1 - obj.nu^2);
            D_el = fac * [1, obj.nu, 0; obj.nu, 1, 0; 0, 0, (1-obj.nu)/2];
            
            % 2. Predictor (Trial Stress)
            % We compute total strain to get trial stress directly from zero
            % (Total Strain implementation is more robust than incremental for hyperelasticity,
            % but here we use small strain incremental logic wrapped in total).
            
            sigma_trial = D_el * eps_total_new; % 3x1 vector [sig_x; sig_y; tau_xy]
            
            % Calculate Von Mises of Trial Stress
            % VM = sqrt( sx^2 + sy^2 - sx*sy + 3*txy^2 )
            sx = sigma_trial(1); sy = sigma_trial(2); txy = sigma_trial(3);
            vm_trial = sqrt(sx^2 + sy^2 - sx*sy + 3*txy^2);
            
            % Current Yield Strength (Isotropic Hardening)
            sig_y_current = obj.YieldStress + obj.H * eps_p_old;
            
            f_yield = vm_trial - sig_y_current;
            
            if f_yield <= 0
                % --- ELASTIC STEP ---
                sigma_new = sigma_trial;
                Dep = D_el;
                eps_p_new = eps_p_old;
            else
                % --- PLASTIC STEP (Return Mapping) ---
                % For Plane Stress, exact return is complex. 
                % We use a simplified projection often sufficient for shells.
                
                % Normal vector to yield surface (flow direction)
                % df/dsigma
                d_vm = 1/vm_trial * [ (sx - 0.5*sy); (sy - 0.5*sx); 3*txy ];
                
                % Plastic Multiplier (Delta Gamma)
                % Solve f(gamma) = 0. Linear approximation:
                % dGamma = f_yield / (H + d_vm' * D_el * d_vm)
                denom = obj.H + d_vm' * D_el * d_vm;
                dGamma = f_yield / denom;
                
                % Correct Stress
                sigma_new = sigma_trial - dGamma * D_el * d_vm;
                
                % Update Plastic Strain
                eps_p_new = eps_p_old + dGamma;
                
                % --- Consistent Tangent Modulus (Dep) ---
                % D_ep = D_el - (D_el*n * n'*D_el) / (H + n'*D_el*n)
                % This ensures quadratic convergence of Newton-Raphson
                vec = D_el * d_vm;
                Dep = D_el - (vec * vec') / denom;
            end
        end
    end
end