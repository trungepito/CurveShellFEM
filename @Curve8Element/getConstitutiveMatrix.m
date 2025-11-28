function [D_mb, D_s] = getConstitutiveMatrix(obj)
            % Returns Material Matrices
            % D_mb: Membrane-Bending (Plane Stress)
            % D_s: Transverse Shear
            
            factor = obj.E / (1 - obj.nu^2);
            
            % Membrane/Bending (Local x, y)
            D_mb = factor * [1,      obj.nu, 0; 
                             obj.nu, 1,      0; 
                             0,      0,      (1-obj.nu)/2];
                             
            % Shear (Local yz, xz) - often formulated with kappa=5/6
            k = 5/6; 
            G = obj.E / (2*(1+obj.nu));
            D_s = k * G * eye(2);
        end