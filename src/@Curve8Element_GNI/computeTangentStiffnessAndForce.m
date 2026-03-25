function [KT, F_int, NewHist] = computeTangentStiffnessAndForce(obj, u_elem)
% Computes Tangent Stiffness (KT) and Internal Force (F_int) for GNI analysis
% u_elem: Current total displacement for this element (40x1)
% KT: 40x40 tangent stiffness matrix
% F_int: 40x1 internal force vector
% NewHist: Empty (no history for GNI)

KT = zeros(40, 40);
F_int = zeros(40, 1);
NewHist = [];  % No history variables

[D_mb, D_s] = obj.getConstitutiveMatrix();
h = obj.Thickness;
Gpoint = 2;  % 2x2 Gauss points for membrane and bending

[g_points, g_weights] = MathFEM.Gauss_p(Gpoint);

for i = 1:Gpoint
    for j = 1:Gpoint
        w = g_weights(i) * g_weights(j);
        xi = g_points(i);
        eta = g_points(j);
        [N, der] = obj.fmisoq8(xi, eta);

        % Kinematics
        [detJ, dNd_local, theta, ~] = obj.calculateKinematics(xi, eta);

        % Construct B-matrices
        [Bm0, Bb0, ~] = obj.formBmb(xi, eta);
        [Bs0, ~] = obj.formBs(xi, eta);

        % Geometric G matrices for nonlinear terms
        Gw = zeros(2, 40);
        Gu = zeros(2, 40);
        Gv = zeros(2, 40);
        for n = 1:8
            idx = (n-1)*5 + (1:5);
            V3_n = obj.Normals(n,:);
            if abs(dot(V3_n, [0,1,0])) < 0.9
                v1n = cross([0,1,0], V3_n);
            else
                v1n = cross([1,0,0], V3_n);
            end
            v1n = v1n / norm(v1n);
            v2n = cross(V3_n, v1n);
            P = theta * v1n';
            Q = -theta * v2n';

            dN_dx = dNd_local(1,n);
            dN_dy = dNd_local(2,n);

            % Update Bs0 for shear (complete assembly)
            Bs0(1, idx(1:3)) = dN_dx * theta(3,:);
            Bs0(2, idx(1:3)) = dN_dy * theta(3,:);
            Bs0(1, idx(4:5)) = N(n) * [P(1), Q(1)];
            Bs0(2, idx(4:5)) = N(n) * [P(2), Q(2)];

            % G matrices
            Gw(1, idx(1:3)) = dN_dx * theta(3,:);
            Gw(2, idx(1:3)) = dN_dy * theta(3,:);
            Gu(1, idx(1:3)) = dN_dx * theta(1,:);
            Gu(2, idx(1:3)) = dN_dy * theta(1,:);
            Gv(1, idx(1:3)) = dN_dx * theta(2,:);
            Gv(2, idx(1:3)) = dN_dy * theta(2,:);
        end

        % Displacement gradients
        theta_kw = Gw * u_elem;
        theta_ku = Gu * u_elem;
        theta_kv = Gv * u_elem;

        % Green-Lagrange strains (von Karman)
        eps_m = Bm0 * u_elem + 0.5 * [theta_kw(1)^2; theta_kw(2)^2; 2*theta_kw(1)*theta_kw(2)] ...
                 + 0.5 * [theta_ku(1)^2; theta_ku(2)^2; 2*theta_ku(1)*theta_ku(2)] ...
                 + 0.5 * [theta_kv(1)^2; theta_kv(2)^2; 2*theta_kv(1)*theta_kv(2)];
        kappa = Bb0 * u_elem;
        gamma = Bs0 * u_elem;

        % Stresses
        N_stress = D_mb(1:3,1:3) * eps_m * h;
        M_stress = D_mb(1:3,1:3) * kappa * (h^3/12);
        Q_stress = D_s * gamma * h;

        % Nonlinear B-matrix
        Aw = [theta_kw(1), 0; 0, theta_kw(2); theta_kw(2), theta_kw(1)];
        Au = [theta_ku(1), 0; 0, theta_ku(2); theta_ku(2), theta_ku(1)];
        Av = [theta_kv(1), 0; 0, theta_kv(2); theta_kv(2), theta_kv(1)];
        BL = Aw * Gw + Au * Gu + Av * Gv;
        Bm_total = Bm0 + BL;

        % Internal force
        f_m = Bm_total' * N_stress;
        f_b = Bb0' * M_stress;
        f_s = Bs0' * Q_stress;
        F_int = F_int + (f_m + f_b + f_s) * detJ * w;

        % Tangent stiffness
        Km = Bm_total' * (D_mb(1:3,1:3) * h) * Bm_total;
        Kb = Bb0' * (D_mb(1:3,1:3) * (h^3/12)) * Bb0;
        Ks = Bs0' * (D_s * h) * Bs0;

        % Geometric stiffness
        S_mtx = [N_stress(1), N_stress(3); N_stress(3), N_stress(2)];
        Kg = Gu' * S_mtx * Gu + Gv' * S_mtx * Gv + Gw' * S_mtx * Gw;

        KT = KT + (Km + Kb + Ks + Kg) * detJ * w;
    end
end
end