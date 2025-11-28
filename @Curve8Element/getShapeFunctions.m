function [N, dN_dxi, dN_deta] = getShapeFunctions(xi, eta)
            % Returns shape functions and local derivatives for 8-node element
            % Nodes 1-4: Corners, 5-8: Midsides
            % Ordering: (-1,-1), (1,-1), (1,1), (-1,1), (0,-1), (1,0), (0,1), (-1,0)
            
            xi_nodes  = [-1,  1,  1, -1,  0,  1,  0, -1];
            eta_nodes = [-1, -1,  1,  1, -1,  0,  1,  0];
            
            N = zeros(1, 8);
            dN_dxi = zeros(1, 8);
            dN_deta = zeros(1, 8);
            
            for i = 1:8
                p = xi_nodes(i);
                q = eta_nodes(i);
                
                if abs(p) == 1 && abs(q) == 1 % Corner nodes
                    term = (1 + xi*p) * (1 + eta*q);
                    last = (xi*p + eta*q - 1);
                    
                    N(i) = 0.25 * term * last;
                    
                    % Derivatives
                    dN_dxi(i)  = 0.25 * p * (1 + eta*q) * (2*xi*p + eta*q);
                    dN_deta(i) = 0.25 * q * (1 + xi*p) * (xi*p + 2*eta*q);
                    
                elseif p == 0 % Midside at xi=0 (Nodes 5, 7)
                    N(i) = 0.5 * (1 - xi^2) * (1 + eta*q);
                    dN_dxi(i)  = -xi * (1 + eta*q);
                    dN_deta(i) = 0.5 * q * (1 - xi^2);
                    
                elseif q == 0 % Midside at eta=0 (Nodes 6, 8)
                    N(i) = 0.5 * (1 + xi*p) * (1 - eta^2);
                    dN_dxi(i)  = 0.5 * p * (1 - eta^2);
                    dN_deta(i) = -eta * (1 + xi*p);
                end
            end
        end