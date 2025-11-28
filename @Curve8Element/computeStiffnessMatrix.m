function Ke = computeStiffnessMatrix(obj)
Ke = zeros(40, 40); % 8 nodes * 5 DOFs

% Gaussian Quadrature
% 3x3 rule is recommended for 8-node elements to prevent hour-glassing
% though 2x2 is sometimes used for shear to prevent locking.
% Here we use 3x3 for simplicity.
g_points = [-sqrt(0.6), 0, sqrt(0.6)];
g_weights = [5/9, 8/9, 5/9];

[D_mb, D_s] = obj.getConstitutiveMatrix();

for i = 1:3
    for j = 1:3
        xi = g_points(i);
        eta = g_points(j);
        w = g_weights(i) * g_weights(j);
        aa=0;
        if aa==1
        [N, dN_dxi, dN_deta] = obj.getShapeFunctions(xi, eta);
        else
        [N,der] = obj.fmisoq8(xi,eta);
        dN_dxi=der(1,:);
        dN_deta=der(2,:);
        end

        % 1. Calculate Jacobian Matrix (3x2 mapping natural to global)
        % We only map the reference surface (zeta=0) derivatives
        J_vec = [0,0,0; 0,0,0]; % [dx/dxi, dy/dxi...; dx/deta...]

        % Interpolate position and V3 vectors
        % pos_int = zeros(1,3);
        V3_int  = zeros(1,3);

        for n = 1:8
            J_vec(1,:) = J_vec(1,:) + dN_dxi(n) * obj.Coords(n,:);
            J_vec(2,:) = J_vec(2,:) + dN_deta(n) * obj.Coords(n,:);

            % pos_int = pos_int + N(n) * obj.Coords(n,:);
            V3_int  = V3_int  + N(n) * obj.Normals(n,:);
        end

        V3_int = V3_int / norm(V3_int); % Normalize interpolated director

        % 2. Local Coordinate System (Cartesian) at Gauss Point
        % v3 = normal, v1 = along xi, v2 = cross(v3, v1)
        v3 = V3_int;
        v1 = J_vec(1,:); % Tangent approx
        v1 = v1 / norm(v1);
        v2 = cross(v3, v1);
        v2 = v2 / norm(v2);
        v1 = cross(v2, v3); % Re-orthogonalize v1

        theta = [v1; v2; v3]; % Rotation matrix Global -> Local

        % 3. Calculate geometric Jacobian considering thickness
        % For shell formulation, we map derivatives to local frame
        % We need derivatives of shape funcs w.r.t local coords (x', y')

        % Surface Jacobian (2x2)
        % J_surf = [d(x_local)/dxi, d(y_local)/dxi; ...]
        J_glob_surf = J_vec;

        % Project J onto local surface
        J_loc = zeros(2,2);
        J_loc(1,1) = dot(J_glob_surf(1,:), v1);
        J_loc(1,2) = dot(J_glob_surf(1,:), v2);
        J_loc(2,1) = dot(J_glob_surf(2,:), v1);
        J_loc(2,2) = dot(J_glob_surf(2,:), v2);

        detJ = det(J_loc);
        invJ = inv(J_loc);

        % Transform natural derivatives to local Cartesian derivatives
        % dN/dx_local = invJ * [dN/dxi; dN/deta]
        dNd_local = invJ * [dN_dxi; dN_deta];

        % 4. Assemble B Matrices
        % Bm: Membrane (strain ep_x, ep_y, gam_xy) -> 3x40
        % Bb: Bending (curvature k_x, k_y, k_xy)  -> 3x40
        % Bs: Shear (gam_yz, gam_xz)              -> 2x40

        Bm = zeros(3, 40);
        Bb = zeros(3, 40);
        Bs = zeros(2, 40);

        % Precompute local vectors V1, V2 at nodes
        % To define alpha/beta rotations, we need nodal coordinate systems.
        % Assume local nodal V1_i is parallel to integration point v1
        % This is a simplification. In full FEM, V1_i and V2_i are stored per node.
        % Here we calculate the contribution of V1_i, V2_i dynamically.

        for n = 1:8
            % Nodal Director vectors
            V3_n = obj.Normals(n,:);

            % Construct local nodal system (v1_n, v2_n, v3_n)
            % We align this roughly with the integration point system for consistency
            if abs(dot(V3_n, [0,1,0])) < 0.9
                v1_n = cross([0,1,0], V3_n);
            else
                v1_n = cross([1,0,0], V3_n);
            end
            v1_n = v1_n / norm(v1_n);
            v2_n = cross(V3_n, v1_n);

            % Transform nodal vectors to Integration Point Local System
            % v1_n_loc = theta * v1_n'

            t1 = theta * v1_n';
            t2 = theta * v2_n';

            % Indices in element stiffness vector
            idx = (n-1)*5 + (1:5);

            % --- Membrane (Bm) ---
            % u, v in local coordinates
            % Strain = [du/dx; dv/dy; du/dy + dv/dx]

            % Transformation of global displ (u,v,w) to local (u',v',w')
            T_mat = theta; % 3x3

            dN_dx = dNd_local(1, n);
            dN_dy = dNd_local(2, n);

            % Column indices for u,v,w
            col_uvw = idx(1:3);

            % Local u contribution
            Bm(1, col_uvw) = dN_dx * T_mat(1,:); % du'/dx'
            Bm(2, col_uvw) = 0;
            Bm(3, col_uvw) = dN_dy * T_mat(1,:);

            % Local v contribution
            Bm(1, col_uvw) = Bm(1, col_uvw) + 0;
            Bm(2, col_uvw) = Bm(2, col_uvw) + dN_dy * T_mat(2,:); % dv'/dy'
            Bm(3, col_uvw) = Bm(3, col_uvw) + dN_dx * T_mat(2,:);

            % --- Bending (Bb) ---
            % CORRECTED LOGIC:
            % DOF 4 (alpha): Rotation about v2_n -> Displaces along +v1_n
            % DOF 5 (beta):  Rotation about v1_n -> Displaces along -v2_n

            col_rot = idx(4:5);

            % Vector P associated with alpha (Rot about v2 -> moves +v1)
            P = t1;
            % Vector Q associated with beta  (Rot about v1 -> moves -v2)
            Q = -t2;

            % k_x = d(rot_u_local)/dx
            % The rotation generates displacement 'u' (local x) and 'v' (local y).
            % u_local_disp = z * (alpha * P(1) + beta * Q(1))
            % v_local_disp = z * (alpha * P(2) + beta * Q(2))

            % k_x (curvature x) corresponds to d(slope)/dx
            Bb(1, col_rot(1)) = dN_dx * P(1);
            Bb(1, col_rot(2)) = dN_dx * Q(1);

            % k_y (curvature y)
            Bb(2, col_rot(1)) = dN_dy * P(2);
            Bb(2, col_rot(2)) = dN_dy * Q(2);

            % k_xy (twist)
            Bb(3, col_rot(1)) = dN_dy * P(1) + dN_dx * P(2);
            Bb(3, col_rot(2)) = dN_dy * Q(1) + dN_dx * Q(2);

            % --- Shear (Bs) ---
            % Transverse Shear strains: gamma_xz, gamma_yz
            % gamma_xz = dw/dx + (rotation of normal about y)
            % gamma_yz = dw/dy - (rotation of normal about x)

            % 1. Derivatives of w
            Bs(1, col_uvw) = dN_dx * T_mat(3,:);
            Bs(2, col_uvw) = dN_dy * T_mat(3,:);

            % 2. Rotation contributions (The Mindlin terms)
            % We project the director displacement vectors P and Q onto the shear plane
            % P is the change in director vector due to alpha
            % Q is the change in director vector due to beta

            % Note: P(3) and Q(3) are the projections onto the normal axis Z.
            % However, standard degenerate shell formulation defines shear strain
            % via the projection of the displacement vector onto the tangent plane.

            % Standard Formulation:
            % Shear = (Displacement deriv) + (Director vector)
            % Here, N(n) * P corresponds to the director vector components.

            Bs(1, col_rot(1)) = Bs(1, col_rot(1)) + N(n) * P(1);
            Bs(1, col_rot(2)) = Bs(1, col_rot(2)) + N(n) * Q(1);

            Bs(2, col_rot(1)) = Bs(2, col_rot(1)) + N(n) * P(2);
            Bs(2, col_rot(2)) = Bs(2, col_rot(2)) + N(n) * Q(2);
        end

        % Integration through thickness
        % Stiffness = B_m' * D_m * B_m * t + B_b' * D_b * B_b * (t^3/12) + Shear

        h = obj.Thickness;

        % Membrane Stiffness (Constant through thickness)
        Km = Bm' * D_mb * Bm * h;

        % Bending Stiffness (z^2 integral -> h^3/12)
        Kb = Bb' * D_mb * Bb * (h^3 / 12);

        % Shear Stiffness (Constant through thickness * shear correction)
        Ks = Bs' * D_s * Bs * h;

        % Total Element Stiffness contribution at this Gauss point
        Ke = Ke + (Km + Kb + Ks) * detJ * w;
    end
end
end

