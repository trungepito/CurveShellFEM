function Kg = computeGeometricStiffness(obj, u_elem)
% Requires the displacement vector u_elem from the static solution
% to calculate the existing membrane forces.

Kg = zeros(40, 40);

% 1. Get Membrane Forces at Center (Simplified: Assumed constant for element)
res = obj.computeStresses(u_elem);
N_vec = res.MembraneForces; % [Nx; Ny; Nxy]

% Stress Matrix S
S = [N_vec(1), N_vec(3);
    N_vec(3), N_vec(2)];

% 2. Integration Loop
g_points = [-sqrt(1/3), sqrt(1/3)]; % 2x2 Gauss for Geometric Stiffness

for i = 1:2
    for j = 1:2
        xi = g_points(i); eta = g_points(j);

        % Recompute Jacobian & Locals (Simplified copy from stiffness)
        [N, dN_dxi, dN_deta] = obj.getShapeFunctions(xi, eta);

        % Jacobian Logic ...
        J_vec = [0,0,0; 0,0,0];
        for n = 1:8
            J_vec(1,:) = J_vec(1,:) + dN_dxi(n) * obj.NodeCoords(n,:);
            J_vec(2,:) = J_vec(2,:) + dN_deta(n) * obj.NodeCoords(n,:);
        end
        % Local frame (Need v1, v2, v3)
        % ... (Assume v1, v2, v3 computed same as in stiffness) ...
        % For brevity in this snippet, we assume J_loc is approx J_glob_surf
        % if the element isn't extremely warped.
        % IN FULL CODE: COPY LOCAL FRAME LOGIC EXACTLY FROM computeStiffnessMatrix

        % Construct G Matrix (Derivatives of w w.r.t local x, y)
        % w is DOF 3 in local.
        % But we are in Global. w_local = T(3,:) * u_global
        % slope_local = d(w_local)/dx_local

        % We need a mapping G (2x40) where:
        % [dw_loc/dx_loc; dw_loc/dy_loc] = G * u_elem

        G = zeros(2, 40);

        % Re-calculate invJ and theta for this gauss point
        % --- REPEAT FRAME LOGIC START ---
        V3_int = zeros(1,3); for n=1:8, V3_int=V3_int+N(n)*obj.NodeNormals(n,:); end
        V3_int = V3_int/norm(V3_int);
        v1 = J_vec(1,:)/norm(J_vec(1,:)); v3=V3_int; v2=cross(v3,v1); v2=v2/norm(v2); v1=cross(v2,v3);
        theta = [v1;v2;v3];
        J_loc = [dot(J_vec(1,:),v1), dot(J_vec(1,:),v2); dot(J_vec(2,:),v1), dot(J_vec(2,:),v2)];
        detJ = det(J_loc); invJ = inv(J_loc);
        dNd_local = invJ * [dN_dxi; dN_deta];
        % --- REPEAT FRAME LOGIC END ---

        % Fill G Matrix
        for n = 1:8
            idx = (n-1)*5 + (1:5);

            dN_dx = dNd_local(1,n);
            dN_dy = dNd_local(2,n);

            % We approximate that buckling is driven by derivatives of translations
            % projected onto the local normal (w).
            % w_local approx = theta(3,1)*u + theta(3,2)*v + theta(3,3)*w

            T_row3 = theta(3, :);

            % Terms for u, v, w
            G(1, idx(1:3)) = dN_dx * T_row3;
            G(2, idx(1:3)) = dN_dy * T_row3;
        end

        Kg = Kg + G' * S * G * detJ;
    end
end
end