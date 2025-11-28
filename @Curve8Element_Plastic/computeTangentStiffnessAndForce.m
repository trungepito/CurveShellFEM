function [KT, F_int, NewHistory] = computeTangentStiffnessAndForce(obj, u_elem)
            KT = zeros(40, 40);
            F_int = zeros(40, 1);
            NewHistory = obj.HistoryData; % Will store updated plastic strains
            
            h = obj.Thickness;
            
            % Integration Scheme:
            % 2x2 Gauss (Area) x 5 Simpson (Thickness)
            g_pts_area = [-sqrt(1/3), sqrt(1/3)];
            
            % Simpson's Rule for thickness (-1 to 1)
            % 5 points: -1, -0.5, 0, 0.5, 1
            nLayers = 5;
            z_pts = linspace(-1, 1, nLayers);
            z_wts = [1, 4, 2, 4, 1] * (2 / (3*(nLayers-1))); % Sum = 2
            
            pt_counter = 0;
            
            for i = 1:2
                for j = 1:2
                    xi = g_pts_area(i); eta = g_pts_area(j);
                    % Area Weight
                    w_area = 1.0; % 2x2 weights are all 1.0
                    
                    % 1. Get Shape Functions & Geometric Jacobian
                    % (Reuse logic from previous Curve8Element...)
                    [N, dN_dxi, dN_deta] = obj.getShapeFunctions(xi, eta);
                    % ... Compute Jacobian, theta, Bm0, Bb0, Bs0, G ...
                    % [For brevity, assume calculateBMatrices() is a helper method]
                    [detJ, Bm0, Bb0, Bs0, G] = obj.calculateKinematics(xi, eta);
                    
                    % Strains (Green-Lagrange)
                    theta_k = G * u_elem;
                    eps_m = Bm0 * u_elem + 0.5 * [theta_k(1)^2; theta_k(2)^2; 2*theta_k(1)*theta_k(2)];
                    kappa = Bb0 * u_elem;
                    gamma = Bs0 * u_elem;
                    
                    % Matrices to accumulate Thickness Integrals
                    A_mat = zeros(3,3); B_mat = zeros(3,3); D_mat = zeros(3,3);
                    Resultant_N = zeros(3,1); Resultant_M = zeros(3,1);
                    
                    % --- THICKNESS LOOP ---
                    for k = 1:nLayers
                        zeta = z_pts(k);
                        w_thick = z_wts(k);
                        z_phys = zeta * h / 2;
                        pt_counter = pt_counter + 1;
                        
                        % Total Strain at this layer
                        % eps(z) = eps_m + z * kappa
                        eps_layer = eps_m + z_phys * kappa;
                        
                        % Retrieve History
                        eps_p_old = obj.HistoryData(pt_counter).eps_p;
                        
                        % CALL MATERIAL MODEL
                        [sig_layer, Dep_layer, eps_p_new] = ...
                            obj.MaterialModel.integrateStress(eps_layer, eps_p_old);
                        
                        % Save New History
                        NewHistory(pt_counter).eps_p = eps_p_new;
                        
                        % Integrate Stress Resultants
                        % Force N = Integral( sigma ) dz
                        % Moment M = Integral( sigma * z ) dz
                        % Weight = w_thick * (h/2) (Jacobian of thickness mapping)
                        dZ = w_thick * (h/2);
                        
                        Resultant_N = Resultant_N + sig_layer * dZ;
                        Resultant_M = Resultant_M + sig_layer * z_phys * dZ;
                        
                        % Integrate Stiffness Matrices (Constitutive)
                        % A = Int(Dep), B = Int(Dep*z), D = Int(Dep*z^2)
                        A_mat = A_mat + Dep_layer * dZ;
                        B_mat = B_mat + Dep_layer * z_phys * dZ;
                        D_mat = D_mat + Dep_layer * (z_phys^2) * dZ;
                    end
                    
                    % --- TRANSVERSE SHEAR (Elastic) ---
                    % We usually assume shear remains elastic (approx) or use simplified J2
                    k_shear = 5/6; 
                    G_mod = obj.E / (2*(1+obj.nu));
                    D_shear = k_shear * G_mod * eye(2) * h;
                    Q_stress = D_shear * gamma; % Resultant Shear Force
                    
                    % --- ASSEMBLE ELEMENT F_int & KT ---
                    
                    % Internal Force
                    % F = Integral( Bm^T * N + Bb^T * M + Bs^T * Q )
                    
                    % Update Bm for Geometric Nonlinearity
                    A_geom = [theta_k(1), 0; 0, theta_k(2); theta_k(2), theta_k(1)];
                    Bm_total = Bm0 + A_geom * G;
                    
                    fe = (Bm_total' * Resultant_N + Bb0' * Resultant_M + Bs0' * Q_stress) * detJ * w_area;
                    F_int = F_int + fe;
                    
                    % Tangent Stiffness
                    % 1. Material Part
                    % [Bm, Bb] * [A B; B D] * [Bm; Bb]'
                    K_mat = Bm_total' * A_mat * Bm_total + ...
                            Bm_total' * B_mat * Bb0 + ...
                            Bb0'      * B_mat * Bm_total + ...
                            Bb0'      * D_mat * Bb0 + ...
                            Bs0'      * D_shear * Bs0;
                            
                    % 2. Geometric Part
                    S_mtx = [Resultant_N(1), Resultant_N(3); Resultant_N(3), Resultant_N(2)];
                    K_geo = G' * S_mtx * G;
                    
                    KT = KT + (K_mat + K_geo) * detJ * w_area;
                end
            end
        end