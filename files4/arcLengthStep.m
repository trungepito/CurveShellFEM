function [u, lambda, F_int, TrialHist, converged, iters] = arcLengthStep(obj, ...
        funcHandle, constraintFn, free_dofs, ...
        u0, lambda0, dup_prev, ...
        arc_length, usePredictor, tol, maxit)
% ARCLENGHTSTEP  One arc-length predictor-corrector increment.
%
% Enhancements vs v3.0:
%   E5 — predictor strategy selection  (obj.Options.PredictorType)
%        'tangent' : standard KT\F_ext  (default, current behaviour)
%        'secant'  : previous increment direction, rescaled to arc_length
%        'auto'    : tangent when condest(KT_ff) < CondLimit, else secant
%
% The CSP sign-flip detection and dlp scaling are identical in all three
% predictor modes — correctness is preserved.
%
% Radius adaptation (E4) is handled by solveArcLengthStage after this
% function returns iters_used.
%
% Residual convention:  R = F_int - lambda * F_ext  (zero at equilibrium).
%
% See also: solveArcLengthStage, SolverOptions

u      = u0;
lambda = lambda0;
F_int  = zeros(length(u0), 1);
TrialHist = {};

opts = obj.Options;

% Initial assembly
[R, KT, fext, TrialHist] = funcHandle(u, lambda, 0, 0);

f_norm = norm(fext(free_dofs));
if f_norm < eps, f_norm = 1.0; end

% ------------------------------------------------------------------
% E5 — Predictor step
% ------------------------------------------------------------------
dup  = zeros(length(u), 1);
dlp  = 0;

if usePredictor
    KT_ff = KT(free_dofs, free_dofs);

    % Guard against singular/near-singular tangent
    if condest(KT_ff) > 1e14
        converged = false; iters = 0; return;
    end

    % Predictor direction selection
    pred_type = opts.PredictorType;

    switch pred_type

        case 'secant'
            % Use the previous converged increment direction.
            % Rescale to unit length — dlp scaling below handles magnitude.
            if norm(dup_prev(free_dofs)) > 1e-12
                dup_f = dup_prev(free_dofs) / norm(dup_prev(free_dofs));
            else
                dup_f = KT_ff \ fext(free_dofs);  % fallback on first step
            end

        case 'auto'
            % Switch based on condition number estimate
            cond_est = condest(KT_ff);
            if cond_est < opts.CondLimit
                dup_f = KT_ff \ fext(free_dofs);
            else
                % Near limit point: KT ill-conditioned — use secant
                if norm(dup_prev(free_dofs)) > 1e-12
                    dup_f = dup_prev(free_dofs) / norm(dup_prev(free_dofs));
                else
                    dup_f = KT_ff \ fext(free_dofs);
                end
            end

        otherwise
            % 'tangent' (default) — standard behaviour
            dup_f = KT_ff \ fext(free_dofs);
    end

    % CSP sign-flip detection (common to all predictor types)
    dup_full             = zeros(length(u), 1);
    dup_full(free_dofs)  = dup_f;

    if norm(dup_prev) < eps
        k0 = 1;
    else
        k0 = dot(dup_prev, dup_full);
    end

    % dlp scaling: arc_length / sqrt(||dup_f||^2 + psi^2)
    % Uses norm(dup_f) so magnitude is consistent regardless of predictor type
    dlp = sign(k0) * arc_length / ...
          (sqrt(norm(dup_f)^2 + obj.ArcLengthPsi^2) + eps);

    dup             = dup_full;
    u               = u0 + dlp * dup;
    lambda          = lambda0 + dlp;

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

    if condest(KT_ff) > 1e14
        converged = false; return;
    end

    % Solve the 2x2 augmented system
    du_I_f  =  KT_ff \ fext_f;
    du_II_f = -KT_ff \ R_f;

    denom = s + h_f' * du_I_f;
    if abs(denom) < 1e-14 * max(abs(s), 1)
        converged = false; return;
    end

    dl = -(g + h_f' * du_II_f) / denom;

    du             = zeros(length(u), 1);
    du(free_dofs)  = dl * du_I_f + du_II_f;

    lambda = lambda + dl;
    u      = u + du;

    [R, KT, fext_current, TrialHist] = funcHandle(u, lambda, 0, 0);

    R_norm = norm(R(free_dofs));
    if R_norm <= tol * f_norm
        converged = true;
        F_int     = R + lambda * fext_current;
        break;
    end
end
end
