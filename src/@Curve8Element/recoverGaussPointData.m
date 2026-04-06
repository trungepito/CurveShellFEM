function gpData = recoverGaussPointData(obj, u_global_48)
% RECOVERGAUSSPOINTDATA  Recover stress/strain at all 20 integration points.
%
% This is the SINGLE authoritative stress-recovery path for post-processing.
% It mirrors the 2x2 in-plane x 5 through-thickness scheme used in
% computeTangentStiffnessAndForce so that recovered stresses are consistent
% with the assembled residual.
%
% Two execution paths:
%   PLASTIC PATH  — element has committed HistoryData (after a converged NL
%                   step).  Stresses are read directly from HistoryData; no
%                   recomputation is needed or wanted.  This is exact.
%
%   ELASTIC PATH  — no MaterialModel / no HistoryData.  Stresses are
%                   computed by replaying the same kinematics as
%                   computeTangentStiffnessAndForce, including the
%                   Green-Lagrange A_geom correction for geometric NL cases.
%
% Input:
%   u_global_48  48x1 global DOF vector for this element (from solver U_Hist)
%
% Output:
%   gpData  struct array [20x1] with fields:
%     .xi, .eta, .zeta   — natural coordinates of this GP
%     .z_phys            — physical through-thickness coordinate (m)
%     .sigma             — [3x1] plane-stress vector [sx; sy; txy]
%     .eps_total         — [3x1] total strain [ex; ey; gxy]
%     .eps_p             — [3x1] plastic strain (zeros if elastic)
%     .p                 — scalar equiv. plastic strain (0 if elastic)
%     .von_mises         — scalar Von Mises stress
%     .sigma_principal   — [2x1] principal stresses [s1; s2]
%     .yielded           — logical: true if p > 0

% ---------------------------------------------------------------
% 0. Strip 48-DOF global vector → 40-DOF mixed-basis vector
%    (exactly the same transform as computeGlobalMatrix6DOF)
% ---------------------------------------------------------------
T       = obj.T_cached;
u_loc   = T * u_global_48;          % rotate to element local frame
u_loc(6:6:end) = [];                % strip drilling DOF → 40x1
u_mix   = obj.per_5_blkdiag() * u_loc;  % permute [u,v,w,Rv1,Rv2]→[u,v,w,α,β]

% ---------------------------------------------------------------
% 1. Integration scheme  (identical to computeTangentStiffnessAndForce)
% ---------------------------------------------------------------
sqrt3_inv = 1 / sqrt(3);
g_pts = [-sqrt3_inv,  sqrt3_inv];

zeta_pts = [-1, -0.5, 0, 0.5,  1];

h        = obj.Thickness;
[D_el, ~] = obj.getConstitutiveMatrix();

% Plastic path: element has a material model AND non-empty history.
% We do NOT test HistoryData(1).p > 0 because p=0 is the correct elastic
% initial state — testing it would force re-integration for every element
% before yield, which is wrong and inconsistent.
% The presence of MaterialModel + HistoryData is the sole gate.
usePlastic = ~isempty(obj.MaterialModel) && ~isempty(obj.HistoryData);

pt = 0;
gpData(20) = struct('xi',0,'eta',0,'zeta',0,'z_phys',0, ...
    'sigma',zeros(3,1),'eps_total',zeros(3,1), ...
    'eps_p',zeros(3,1),'p',0, ...
    'von_mises',0,'sigma_principal',zeros(2,1),'yielded',false);

for i = 1:2
    for j = 1:2
        xi  = g_pts(i);
        eta = g_pts(j);

        % Single kinematics call — shares detJ and dNd_local with A_geom build
        [~, dNd_local, ~, ~] = obj.calculateKinematics(xi, eta);
        [Bm0, Bb0]           = obj.formBmb(xi, eta);
        G = zeros(2, 40);
        for n = 1:8
            G(1, (n-1)*5 + 1) = dNd_local(1, n);
            G(2, (n-1)*5 + 2) = dNd_local(2, n);
        end
        theta_k  = G * u_mix;
        A_geom   = [theta_k(1), 0;
                    0,          theta_k(2);
                    theta_k(2), theta_k(1)];

        % Membrane and bending strains (consistent with assembly)
        eps_m  = Bm0 * u_mix + 0.5 * A_geom * theta_k;
        kappa  = Bb0 * u_mix;

        % Through-thickness layers
        for k = 1:5
            pt      = pt + 1;
            zeta    = zeta_pts(k);
            z_phys  = zeta * h / 2;

            eps_total = eps_m + z_phys * kappa;

            if usePlastic
                % ── PLASTIC PATH: read committed state directly ──────────
                sigma  = obj.HistoryData(pt).sigma;
                eps_p  = obj.HistoryData(pt).eps_p;
                p_val  = obj.HistoryData(pt).p;
            else
                % ── ELASTIC PATH: compute from total strain ──────────────
                sigma  = D_el * eps_total;
                eps_p  = zeros(3,1);
                p_val  = 0;
            end

            % Derived quantities
            sx   = sigma(1);  sy = sigma(2);  txy = sigma(3);
            vm   = sqrt(sx^2 + sy^2 - sx*sy + 3*txy^2);

            % Principal stresses (plane stress, in-plane only)
            avg    = (sx + sy) / 2;
            radius = sqrt(((sx - sy)/2)^2 + txy^2);
            s1     = avg + radius;
            s2     = avg - radius;

            gpData(pt).xi              = xi;
            gpData(pt).eta             = eta;
            gpData(pt).zeta            = zeta;
            gpData(pt).z_phys          = z_phys;
            gpData(pt).sigma           = sigma;
            gpData(pt).eps_total       = eps_total;
            gpData(pt).eps_p           = eps_p;
            gpData(pt).p               = p_val;
            gpData(pt).von_mises       = vm;
            gpData(pt).sigma_principal = [s1; s2];
            gpData(pt).yielded         = (p_val > 1e-10);
        end
    end
end
end
