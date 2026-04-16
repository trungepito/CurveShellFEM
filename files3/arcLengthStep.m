function [u, lambda, F_int, TrialHist, converged, iters] = arcLengthStep(obj, ...
        funcHandle, constraintFn, free_dofs, ...
        u0, lambda0, dup_prev, ...
        arc_length, usePredictor, tol, maxit)
% ARCLENGHTSTEP  One arc-length predictor-corrector increment.
%
% ============================================================
% Enhancement log  (P1.1, P1.2, P1.3, P2.1, P3.1, P3.3, P4.1, P4.2)
% ============================================================
%
% P1.1  condest() replacement
%       condest always returns >= 1; the old threshold 1e-14 was
%       unreachable. Singularity is now detected via rcond() on the
%       reduced system.  rcond < RCOND_THRESH triggers an early return
%       with a warning, consistent with how mldivide reports rank
%       deficiency.
%
% P1.2  Residual sign audit
%       Convention: R = F_int - lambda * F_ext
%       Equilibrium: R = 0  <=>  F_int = lambda * F_ext
%       Newton direction: KT * du = -R  (pointing toward equilibrium)
%       This is now explicitly documented at every solve site.
%
% P1.3  Riks denominator guard strengthened
%       The old guard tested only |s| < threshold.  When dup is nearly
%       orthogonal to du_I the full denominator (s + h'*du_I) can be
%       near zero even when s is fine.  The new guard uses a relative
%       threshold:  |raw_denom| < 1e-10 * (|s| + ||h|| * ||du_I||).
%
% P2.1  Backtracking line search in corrector
%       After computing (dl, du) the step length eta is halved up to
%       LS_MAXIT times when the residual does not satisfy an Armijo
%       sufficient-decrease condition.  Only the displacement part is
%       backtracked; dl is kept fixed to preserve constraint satisfaction.
%
% P3.1  Dimensionally consistent arc-length metric
%       The predictor normalisation now uses psi * ||F_ext|| so the
%       mixed  ds^2 = ||du||^2 + (psi * ||F_ext||)^2 * dlambda^2  is
%       dimensionally homogeneous.  The original code mixed displacement
%       units with the dimensionless psi^2 directly.
%
% P3.3  Energy convergence criterion (secondary check)
%       |du . R| / |du_1 . R_1|  < tol^2  catches stagnation when the
%       residual norm plateaus but never crosses the primary threshold.
%
% P4.1  Elastic-constant KT fast path
%       When the solver has flagged KT_is_elastic_constant = true (set by
%       assembleTangentSystem after detecting a purely elastic material),
%       the tangent is assembled only at the first corrector iteration and
%       then reused.  Only F_int is updated cheaply via
%       assembleinternalforceONLY on subsequent iterations.
%
% P4.2  Single LU factorisation per corrector iteration
%       KT_ff is factorised once with lu() and the same L, U, P, Q
%       factors are used for both RHS solves (du_I and du_II), halving
%       the number of triangular solves per iteration compared to two
%       separate backslash calls.

% ── Tuning constants ─────────────────────────────────────────────────────
LS_MAXIT     = 5;        % max backtracking steps (P2.1)
LS_FACTOR    = 0.5;      % step-length reduction per backtrack
LS_ARMIJO    = 1e-4;     % Armijo sufficient-decrease coefficient
RCOND_THRESH = 1e-13;    % rcond below this => near-singular (P1.1)

% ── Initialise ───────────────────────────────────────────────────────────
n         = length(u0);
u         = u0;
lambda    = lambda0;
F_int     = zeros(n, 1);
TrialHist = {};

% First full assembly — always needed even on elastic fast path
[R, KT, fext, TrialHist] = funcHandle(u, lambda, 0, 0);

% P4.1: query elastic-constant flag set by assembleTangentSystem
elastic_const = isprop(obj, 'KT_is_elastic_constant') && obj.KT_is_elastic_constant;

% Reference force norm — switch to absolute when F_ext is near zero (P2.4)
f_norm = norm(fext(free_dofs));
if f_norm < 1e-10 * max(abs(fext(:)))
    f_norm = 1.0;
end

% ── Predictor  (Riks only) ───────────────────────────────────────────────
dup = zeros(n, 1);
dlp = 0;

if usePredictor
    KT_ff_pred = KT(free_dofs, free_dofs);

    % P1.1: singularity check
    rc_pred = rcond(full(KT_ff_pred));
    if rc_pred < RCOND_THRESH
        converged = false; iters = 0;
        warning('arcLengthStep:singularPredictor', ...
            'KT near-singular at predictor (rcond=%.2e). Step skipped.', rc_pred);
        return;
    end

    dup_f = KT_ff_pred \ fext(free_dofs);
    dup(free_dofs) = dup_f;

    % CSP sign flip
    if norm(dup_prev) < eps
        k0 = 1;
    else
        k0 = dot(dup_prev, dup);
    end
    sgn = 1; if k0 < 0, sgn = -1; end

    % P3.1: dimensionally consistent denominator
    psi_eff    = obj.ArcLengthPsi * f_norm;
    denom_pred = sqrt(norm(dup_f)^2 + psi_eff^2);
    if denom_pred < eps, denom_pred = 1.0; end

    dlp    = sgn * arc_length / denom_pred;
    u      = u0 + dlp * dup;
    lambda = lambda0 + dlp;

    % Reassemble at predicted point
    [R, KT, ~, TrialHist] = funcHandle(u, lambda, 0, 0);
    % Refresh elastic flag after second assembly
    elastic_const = isprop(obj, 'KT_is_elastic_constant') && obj.KT_is_elastic_constant;
end

% ── Corrector loop ───────────────────────────────────────────────────────
converged    = false;
iters        = 0;
R_norm_prev  = norm(R(free_dofs));
energy_first = [];
KT_frozen    = KT;    % P4.1: frozen copy for elastic reuse

for i = 1 : maxit
    iters = i;

    % P4.1: elastic fast path — only update F_int, keep KT frozen.
    % Fixed-DOF indices come from obj.fixedDofsCache_ALS which is populated
    % by solveArcLengthStage before the trial loop begins.
    if elastic_const && i > 1
        F_int_raw = obj.assembleinternalforceONLY(u);
        R         = F_int_raw - lambda * fext;
        if isprop(obj, 'fixedDofsCache_ALS') && ~isempty(obj.fixedDofsCache_ALS)
            R(obj.fixedDofsCache_ALS) = 0;
        end
        % KT stays as KT_frozen — no re-assembly needed
    else
        KT_frozen = KT;
    end

    % P4.2: extract reduced system, factorise once per iteration
    KT_ff  = KT_frozen(free_dofs, free_dofs);
    R_f    = R(free_dofs);
    fext_f = fext(free_dofs);

    % P1.1: check reduced tangent before factorising
    rc = rcond(full(KT_ff));
    if rc < RCOND_THRESH
        converged = false;
        warning('arcLengthStep:singularCorrectorKT', ...
            'KT near-singular at corrector iter %d (rcond=%.2e).', i, rc);
        return;
    end

    % P4.2: single LU, two triangular solves
    [L_f, U_f, P_lu, Q_lu] = lu(KT_ff);
    solve_f = @(b) Q_lu * (U_f \ (L_f \ (P_lu * b)));

    du_I_f  =  solve_f(fext_f);    % tangent response to load increment
    du_II_f =  solve_f(-R_f);      % P1.2: Newton direction toward R=0

    % ── Constraint evaluation ────────────────────────────────────────────
    h_free = zeros(length(free_dofs), 1);
    [g, h_free_out, s] = constraintFn(u, lambda, u0, lambda0, dup, dlp, arc_length);

    % constraintFn returns h on FREE dofs (same size as u in Riks, full n in others)
    if length(h_free_out) == n
        h_f = h_free_out(free_dofs);
    else
        h_f = h_free_out;
    end

    % P1.3: full-denominator guard — tests the sum, not just s
    raw_denom   = s + h_f' * du_I_f;
    scale_denom = abs(s) + norm(h_f) * norm(du_I_f) + eps;
    if abs(raw_denom) < 1e-10 * scale_denom
        converged = false;
        warning('arcLengthStep:degenerateConstraint', ...
            'Arc-length denominator near zero at iter %d (ratio=%.2e).', ...
            i, abs(raw_denom) / scale_denom);
        return;
    end

    dl        = -(g + h_f' * du_II_f) / raw_denom;
    du_full_f = dl * du_I_f + du_II_f;

    % ── P2.1: backtracking line search ───────────────────────────────────
    eta        = 1.0;
    lambda_new = lambda + dl;
    u_ls       = u;
    u_ls(free_dofs) = u(free_dofs) + eta * du_full_f;

    [R_ls, KT_ls, fext_ls, TH_ls] = funcHandle(u_ls, lambda_new, 0, 0);
    R_norm_ls = norm(R_ls(free_dofs));

    for ls_iter = 1 : LS_MAXIT
        armijo_ok = R_norm_ls < (1 - LS_ARMIJO * eta) * R_norm_prev + eps;
        converged_in_ls = R_norm_ls < tol * f_norm;
        if armijo_ok || converged_in_ls, break; end

        eta = eta * LS_FACTOR;
        u_ls(free_dofs) = u(free_dofs) + eta * du_full_f;
        [R_ls, KT_ls, fext_ls, TH_ls] = funcHandle(u_ls, lambda_new, 0, 0);
        R_norm_ls = norm(R_ls(free_dofs));
    end

    % Accept the line-searched iterate
    u           = u_ls;
    lambda      = lambda_new;
    R           = R_ls;
    KT          = KT_ls;
    fext        = fext_ls;
    TrialHist   = TH_ls;
    R_norm_prev = R_norm_ls;

    % ── P3.3: energy convergence criterion ───────────────────────────────
    energy_curr = abs(eta * (du_full_f' * R_f));
    if isempty(energy_first) && energy_curr > 0
        energy_first = energy_curr;
    end

    % ── Convergence tests ────────────────────────────────────────────────
    if R_norm_ls <= tol * f_norm
        converged = true;
        F_int = R_ls + lambda * fext_ls;
        break;
    end

    if ~isempty(energy_first) && energy_first > 0
        if energy_curr / energy_first < tol^2
            converged = true;
            F_int = R_ls + lambda * fext_ls;
            break;
        end
    end
end

% Always return a valid F_int on convergence
if converged && max(abs(F_int)) < eps * max(abs(R(:)))
    F_int = R + lambda * fext;
end

end
