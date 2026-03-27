function [KT, F_int, NewHistory] = computeTangentStiffnessAndForce(obj, u_elem)
% computeTangentStiffnessAndForce: ANS/EAS with split integration.
%   - Shear:            2x2 Gauss, ANS-interpolated Bs
%   - Membrane/Bending: 3x3 Gauss x 5 thickness layers, EAS condensed

    KT_uu = zeros(40, 40);
    KT_ua = zeros(40, 4);
    KT_aa = zeros(4, 4);
    F_int_u = zeros(40, 1);

    NewHistory = obj.HistoryData;
    h = obj.Thickness;
    [D_el, D_s] = obj.getConstitutiveMatrix();
    k_shear = 5/6;

    nLayer = 5;
    [gp2, gw2] = MathFEM.Gauss_p(2);
    [gp3, gw3] = MathFEM.Gauss_p(3);
    [gp_z, gw_z] = MathFEM.Gauss_p(nLayer);

    % ================================================================
    % PART 1 – Transverse Shear (2x2, ANS)
    % ================================================================
    for i = 1:2
        for j = 1:2
            xi = gp2(i); eta = gp2(j);
            w_surf = gw2(i) * gw2(j);

            [detJ, ~, ~, ~] = obj.calculateKinematics(xi, eta);
            [Bs0, ~]        = obj.formBs(xi, eta);   % ANS-overridden

            gamma_comp = Bs0 * u_elem;
            Q_res      = D_s * gamma_comp * h * k_shear;
            F_int_u    = F_int_u + (Bs0' * Q_res) * detJ * w_surf;
            KT_uu      = KT_uu   + (Bs0' * (D_s * h * k_shear) * Bs0) * detJ * w_surf;
        end
    end

    % ================================================================
    % PART 2 – Membrane / Bending / EAS (3x3 x 5 layers)
    % ================================================================
    pt_counter = 0;
    for i = 1:3
        for j = 1:3
            xi = gp3(i); eta = gp3(j);
            w_surf = gw3(i) * gw3(j);

            [detJ, dNd_local, ~, ~] = obj.calculateKinematics(xi, eta);
            [Bm0, Bb0]              = obj.formBmb(xi, eta);
            M                       = obj.formM(xi, eta);

            % Geometric nonlinearity scaffold
            G = zeros(2, 40);
            for n = 1:8
                G(1, (n-1)*5 + 1) = dNd_local(1, n);
                G(2, (n-1)*5 + 2) = dNd_local(2, n);
            end
            theta_k = G * u_elem;
            A_geom  = [theta_k(1), 0; 0, theta_k(2); theta_k(2), theta_k(1)];
            Bm_total = Bm0 + A_geom * G;

            A_mat = zeros(3,3); B_mat = zeros(3,3); D_mat = zeros(3,3);
            Res_N = zeros(3,1); Res_M = zeros(3,1);

            for k = 1:nLayer
                z      = gp_z(k);
                w_z    = gw_z(k) * (h/2);
                dV     = detJ * w_surf * w_z;
                pt_counter = pt_counter + 1;

                eps_total = (Bm0*u_elem + 0.5*A_geom*theta_k) + z*Bb0*u_elem + M(1:3,:)*obj.AlphaEAS;

                if ~isempty(obj.MaterialModel)
                    [sig_new, Dep_new, eps_p_new, p_new] = obj.MaterialModel.integrateStress( ...
                        eps_total, obj.HistoryData(pt_counter).eps_p, obj.HistoryData(pt_counter).p);
                    NewHistory(pt_counter).sigma = sig_new;
                    NewHistory(pt_counter).eps_p = eps_p_new;
                    NewHistory(pt_counter).p     = p_new;
                else
                    sig_new = D_el * eps_total; Dep_new = D_el;
                end

                Res_N = Res_N + sig_new * w_z;
                Res_M = Res_M + sig_new * z * w_z;
                A_mat = A_mat + Dep_new * w_z;
                B_mat = B_mat + Dep_new * z  * w_z;
                D_mat = D_mat + Dep_new * z^2 * w_z;

                KT_ua = KT_ua + (Bm_total + z*Bb0)' * Dep_new * M(1:3,:) * dV;
                KT_aa = KT_aa +  M(1:3,:)'           * Dep_new * M(1:3,:) * dV;
            end

            F_int_u = F_int_u + (Bm_total'*Res_N + Bb0'*Res_M) * detJ * w_surf;
            Ke_mat  = (Bm_total'*A_mat*Bm_total + Bm_total'*B_mat*Bb0 + ...
                       Bb0'*B_mat*Bm_total      + Bb0'*D_mat*Bb0     ) * detJ * w_surf;
            S_mtx   = [Res_N(1), Res_N(3); Res_N(3), Res_N(2)];
            Ke_geo  = (G' * S_mtx * G) * detJ * w_surf;
            KT_uu   = KT_uu + Ke_mat + Ke_geo;
        end
    end

    % ================================================================
    % PART 3 – Static condensation
    % ================================================================
    KT    = KT_uu - KT_ua * (KT_aa \ KT_ua');
    F_int = F_int_u;
end
