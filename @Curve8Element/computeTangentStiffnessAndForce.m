function [KT, F_int] = computeTangentStiffnessAndForce(obj, u_elem)
% Computes Tangent Stiffness (KT) and Internal Force (F_int)
% u_elem: Current total displacement for this element (40x1)

KT = zeros(40, 40);
F_int = zeros(40, 1);

[D_mb, D_s] = obj.getConstitutiveMatrix();
h = obj.Thickness;
Gpoint=2;% number of gauss points for Membrane and Bending term

[g_points,g_weights]=MathFEM.Gauss_p(Gpoint);
% Gauss Integration (2x2 is standard for nonlinear loops to save time)
% g_points = [-sqrt(1/3), sqrt(1/3)];

for i = 1:Gpoint
    for j = 1:Gpoint
        w=g_weights(i)*g_weights(j);
        xi = g_points(i); eta = g_points(j);
        [N,der ] = obj.fmisoq8(xi, eta);
        % dN_dxi=der(1,:); dN_deta=der(2,:);
        % --- 1. Geometry & Jacobian (Same as Linear) ---
        J_vec=der*obj.Coords;
        V3_int=N*obj.Normals;
        V3_int = V3_int/norm(V3_int);
        v1 = J_vec(1,:)/norm(J_vec(1,:)); v3 = V3_int;
        v2 = cross(v3,v1); v2 = v2/norm(v2); v1 = cross(v2,v3);
        theta = [v1; v2; v3];

        J_loc = [dot(J_vec(1,:),v1), dot(J_vec(1,:),v2);
            dot(J_vec(2,:),v1), dot(J_vec(2,:),v2)];
        detJ = det(J_loc);
        invJ = J_loc\eye(2);
        dNd_local = invJ * der;

        % --- 2. Construct Linear B-Matrices (B0) ---
        % (Simplified reconstruction of Bm, Bb, Bs from previous code)
        Bm0 = zeros(3, 40); Bb0 = zeros(3, 40); Bs0 = zeros(2, 40);

        % Matrix G for Geometric nonlinear derivatives (dw/dx, dw/dy)
        G = zeros(2, 40);

        for n = 1:8
            idx = (n-1)*5 + (1:5);
            V3_n = obj.Normals(n,:);
            if abs(dot(V3_n,[0,1,0]))<0.9, v1n=cross([0,1,0],V3_n); else, v1n=cross([1,0,0],V3_n); end
            v1n=v1n/norm(v1n); v2n=cross(V3_n,v1n);
            % T_node = [theta*v1n', theta*v2n']; % 3x2 projection

            dN_dx = dNd_local(1,n); dN_dy = dNd_local(2,n);

            % Linear Membrane B0
            Bm0(1, idx(1:3)) = dN_dx * theta(1,:);
            Bm0(2, idx(1:3)) = dN_dy * theta(2,:);
            Bm0(3, idx(1:3)) = dN_dy * theta(1,:) + dN_dx * theta(2,:);

            % Linear Bending Bb0 (Simplified for brevity)
            P = theta*v1n'; Q = -theta * v2n';
            Bb0(1, idx(4:5)) = [dN_dx*P(1), dN_dx*Q(1)];
            Bb0(2, idx(4:5)) = [dN_dy*P(2), dN_dy*Q(2)];
            Bb0(3, idx(4:5)) = [dN_dy*P(1)+dN_dx*P(2), dN_dy*Q(1)+dN_dx*Q(2)];

            % Shear Bs0
            Bs0(1, idx(1:3)) = dN_dx * theta(3,:);
            Bs0(2, idx(1:3)) = dN_dy * theta(3,:);
            Bs0(1, idx(4:5)) = Bs0(1, idx(4:5)) + N(n)*[P(1), Q(1)];
            Bs0(2, idx(4:5)) = Bs0(2, idx(4:5)) + N(n)*[P(2), Q(2)];

            % Geometric G Matrix (Slope derivatives)
            % Approx: Slopes of 'w' in local system
            G(1, idx(1:3)) = dN_dx * theta(3,:); % d(w_loc)/dx
            G(2, idx(1:3)) = dN_dy * theta(3,:); % d(w_loc)/dy
        end

        % --- 3. Calculate Current Strains & Stresses ---
        % Displacement gradient vector theta_k = G * u
        theta_k = G * u_elem;

        % Green-Lagrange Strain (Von Karman: Linear + 0.5*slope^2)
        % Membrane Strain
        eps_m = Bm0 * u_elem + 0.5 * [theta_k(1)^2; theta_k(2)^2; 2*theta_k(1)*theta_k(2)];
        % Bending/Shear Strains (Assumed Linear)
        kappa = Bb0 * u_elem;
        gamma = Bs0 * u_elem;

        % Stresses (S = D * E)
        N_stress = D_mb(1:3,1:3) * eps_m * h; % Resultant Membrane Forces
        M_stress = D_mb(1:3,1:3) * kappa * (h^3/12);
        Q_stress = D_s * gamma * h;

        % --- 4. Internal Force Vector (F_int) ---
        % F_int = Integral( B_nonlinear^T * Stress )
        % BN = B0 + BL(u)
        % We assemble contribution by contribution

        % A matrix (Gradient of w)
        A = [theta_k(1), 0; 0, theta_k(2); theta_k(2), theta_k(1)];

        % Total Membrane B-Matrix: B_m = Bm0 + A * G
        BL = A * G;
        Bm_total = Bm0 + BL;

        f_m = Bm_total' * N_stress;
        f_b = Bb0' * M_stress;
        f_s = Bs0' * Q_stress;

        F_int = F_int + (f_m + f_b + f_s) * detJ*w;

        % --- 5. Tangent Stiffness Matrix (KT) ---
        % KT = K_material + K_geometric

        % K_material = B_total' * D * B_total
        Km = Bm_total' * (D_mb(1:3,1:3)*h) * Bm_total;
        Kb = Bb0' * (D_mb(1:3,1:3)*(h^3/12)) * Bb0;
        Ks = Bs0' * (D_s*h) * Bs0;

        % K_geometric = G' * S_stress * G
        % Stress matrix for geometric stiffness
        S_mtx = [N_stress(1), N_stress(3); N_stress(3), N_stress(2)];
        Kg = G' * S_mtx * G;

        KT = KT + (Km + Kb + Ks + Kg) * detJ*w;
    end
end
end