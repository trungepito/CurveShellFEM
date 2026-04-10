function [u, lambda, F_int, TrialHist, converged, iters] = arcLengthStep(obj, ...
        funcHandle, constraintFn, free_dofs, ...
        u0, lambda0, dup_prev, ...
        arc_length, usePredictor, tol, maxit)
% ARCLENGHTSTEP  One arc-length predictor-corrector increment.
%
% v3.6: Solve-validation path with shared corrector linear solve.
% - Residual convention: R = F_int - lambda * F_ext
% - Single-threaded CPU assembly via funcHandle triplets.
% - Performance: Returns F_int/TrialHist from final iteration; NO redundant assembly.
% - Robustness: validates reduced linear solves using finite checks and
%   relative residual thresholds (works for sparse/direct backslash path).
% - Performance: corrector solves both RHS vectors in one linear solve.

% Initialise at the beginning of the step
u      = u0;
lambda = lambda0;
F_int  = zeros(length(u0), 1);
TrialHist = {};

% Initial assembly for predictor
[R, KT, fext, TrialHist] = funcHandle(u, lambda, 0, 0);

% Reference norm for relative convergence criterion
f_norm = norm(fext(free_dofs));
if f_norm < eps, f_norm = 1.0; end

% ------------------------------------------------------------------
% Predictor step (Riks only)
% ------------------------------------------------------------------
dup = zeros(length(u), 1);
dlp = 0;

if usePredictor
    KT_ff = KT(free_dofs, free_dofs);
    [ok_pred, dup_f] = solveReducedSystem(KT_ff, fext(free_dofs));
    if ~ok_pred
        converged = false; iters = 0; return;
    end

    dup(free_dofs) = dup_f;

    % CSP sign flip detection
    if norm(dup_prev) < eps
        k0 = 1;
    else
        k0 = dot(dup_prev, dup);
    end

    if k0 >= 0
        dlp =  arc_length / (sqrt(norm(dup_f)^2 + obj.ArcLengthPsi^2) + eps);
    else
        dlp = -arc_length / (sqrt(norm(dup_f)^2 + obj.ArcLengthPsi^2) + eps);
    end

    u      = u0 + dlp * dup;
    lambda = lambda0 + dlp;

    % Re-assemble at predicted state
    [R, KT, ~, TrialHist] = funcHandle(u, lambda, 0, 0);
end

% ------------------------------------------------------------------
% Corrector loop (augmented Newton-Raphson)
% ------------------------------------------------------------------
converged = false;
iters     = 0;

for i = 1 : maxit
    iters = i;

    [g, h, s] = constraintFn(u, lambda, u0, lambda0, dup, dlp, arc_length);

    KT_ff  = KT(free_dofs, free_dofs);
    R_f    = R(free_dofs);
    fext_f = fext(free_dofs);
    h_f    = h(free_dofs);

    rhs = [fext_f, -R_f];
    [ok_lin, DU] = solveReducedSystem(KT_ff, rhs);
    if ~ok_lin
        converged = false; return;
    end

    % Solve for increment: du = dl * du_I + du_II
    % du_I  = Response to tangent Load fext
    % du_II = Response to residual -R (where R = F_int - lambda*F_ext)
    du_I_f  = DU(:,1);
    du_II_f = DU(:,2);

    denom = s + h_f' * du_I_f;
    if abs(denom) < 1e-14 * max(abs(s), 1)
        converged = false; return;
    end

    dl = -(g + h_f' * du_II_f) / denom;

    du = zeros(length(u), 1);
    du(free_dofs) = dl * du_I_f + du_II_f;

    lambda = lambda + dl;
    u      = u + du;

    % Final assembly of the iteration
    % Returns F_int indirectly through R = F_int - lambda * F_ext
    [R, KT, fext_current, TrialHist] = funcHandle(u, lambda, 0, 0);

    R_norm = norm(R(free_dofs));
    if R_norm <= tol * f_norm
        converged = true;
        % Recover F_int from the last residual and load
        F_int = R + lambda * fext_current;
        break;
    end
end

end

% -------------------------------------------------------------------------
function [ok, X] = solveReducedSystem(KT_ff, B)
% SOLVEREDUCEDSYSTEM  Solve KT_ff * X = B with numerical sanity checks.
%
% We avoid explicit condition-number estimates here because they are noisy
% and expensive in nonlinear loops. Instead, we validate the solve result:
%   1) all entries finite
%   2) relative residual below tolerance

X = KT_ff \ B;

if any(~isfinite(X(:)))
    ok = false;
    return;
end

res = KT_ff * X - B;
rel_res = norm(res, 'fro') / max(norm(B, 'fro'), 1.0);
ok = isfinite(rel_res) && (rel_res <= 1e-8);

end
