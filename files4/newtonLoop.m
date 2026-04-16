function [converged, U_out, reaction, iter, diagOut] = newtonLoop(obj, F_external, U_curr, fixed_dofs)
% NEWTONLOOP  Augmented Newton-Raphson corrector with E1-E3, E6 enhancements.
%
% Enhancements active when enabled in obj.Options (SolverOptions):
%   E1 — mixed force/displacement/energy convergence criteria
%   E2 — Armijo backtracking line search  (UseLineSearch = true)
%   E3 — L-BFGS quasi-Newton updates      (UseQuasiNewton = true)
%   E6 — ConvergenceMonitor diagnostics   (always active, zero-cost if ignored)
%
% Signature change vs v3.0: added 5th output diagOut (struct with per-iter
% residual history).  Callers that ignore the 5th output are unaffected.
%
% Residual convention: R = F_int - F_external  (equilibrium at R = 0).
%
% See also: SolverOptions, ConvergenceMonitor, armijoSearch, lbfgsDirection

opts      = obj.Options;
nDofs     = length(U_curr);
free_dofs = setdiff(1:nDofs, fixed_dofs);

% ------------------------------------------------------------------
% Reference norms (computed once — not updated per iteration)
% ------------------------------------------------------------------
% Force reference: magnitude of the applied external load on free DOFs.
% Protected against zero for pure displacement-controlled stages.
f_ref = norm(F_external(free_dofs));
if f_ref < 1e-14
    f_ref = 1.0;
end

% ------------------------------------------------------------------
% Output initialisation
% ------------------------------------------------------------------
converged = false;
TrialHist = [];
diagOut   = struct('force', [], 'disp', [], 'energy', []);

% ------------------------------------------------------------------
% E6 — Convergence monitor
% ------------------------------------------------------------------
monitor = ConvergenceMonitor(opts);
monitor.reset();

% ------------------------------------------------------------------
% E3 — L-BFGS history buffers (free-DOF vectors only)
% ------------------------------------------------------------------
s_list = {};   % cell of displacement increments  s_k = alpha*dU_f
y_list = {};   % cell of residual increments       y_k = R_new - R_old
R_prev = [];   % previous-iteration residual (free DOFs)

% ------------------------------------------------------------------
% E1 — Energy reference: fixed at first iteration
% ------------------------------------------------------------------
E_ref = [];

% ==================================================================
% Main Newton loop
% ==================================================================
for iter = 1 : opts.MaxIterations

    % ---- 1. Assemble tangent system ----
    [Kt, F_int, TrialHist] = obj.assembleTangentSystem(U_curr);
    R = F_int - F_external;

    % ---- 2. Compute Newton direction (or L-BFGS direction) ----
    KT_ff = Kt(free_dofs, free_dofs);
    R_f   = R(free_dofs);

    if opts.UseQuasiNewton && ~isempty(s_list)
        % E3: attempt L-BFGS direction
        [p_free, lbfgs_ok] = lbfgsDirection(s_list, y_list, R_f, opts);
        if lbfgs_ok
            dU_f = -p_free;
        else
            % Curvature condition failed — fall back to Newton, reset history
            dU_f   = KT_ff \ (-R_f);
            s_list = {};
            y_list = {};
        end
    else
        % Standard Newton direction
        dU_f = KT_ff \ (-R_f);
    end

    % ---- 3. E1: energy reference fixed at first iteration ----
    if isempty(E_ref)
        E_ref = max(abs(dU_f' * R_f), opts.EnergyFloor);
    end

    % ---- 4. E1: three convergence criteria ----
    err_f = norm(R_f) / f_ref;
    err_d = norm(dU_f) / max(norm(U_curr(free_dofs)), opts.DispFloor);
    err_e = abs(dU_f' * R_f) / E_ref;

    diagOut.force(end+1)  = err_f;
    diagOut.disp(end+1)   = err_d;
    diagOut.energy(end+1) = err_e;

    % ---- 5. E6: record and check monitor ----
    monitor.record(err_f, err_e);
    action = monitor.recommend();

    if strcmp(action, 'abort')
        fprintf('[Newton] iter %d: divergence detected (R/R0=%.1e). Abandoning step.\n', ...
            iter, err_f / max(diagOut.force(1), 1e-30));
        break;
    end

    % ---- 6. Convergence check (all three criteria, AND) ----
    if err_f < opts.TolForce && err_d < opts.TolDisp && err_e < opts.TolEnergy
        converged = true;
        U_out     = U_curr;
        reaction  = F_int(fixed_dofs);
        obj.commitHistory(TrialHist);
        return;
    end

    % ---- 7. E2: line search (Armijo backtracking) ----
    alpha = 1.0;
    need_ls = opts.UseLineSearch || strcmp(action, 'linesearch');
    if need_ls
        alpha = obj.armijoSearch(U_curr, dU_f, R, F_external, free_dofs, opts);
    end

    % ---- 8. E3: update L-BFGS history ----
    if opts.UseQuasiNewton && ~isempty(R_prev)
        s_new = alpha * dU_f;
        y_new = R_f - R_prev;
        ys    = y_new' * s_new;
        if ys > opts.LBFGSCurvEps
            s_list{end+1} = s_new;  %#ok<AGROW>
            y_list{end+1} = y_new;  %#ok<AGROW>
            if numel(s_list) > opts.LBFGSHistory
                s_list(1) = [];
                y_list(1) = [];
            end
        end
        % Reset history when new plasticity occurs (consistent tangent lost)
        if opts.ResetOnPlastic && obj.newPlasticYieldOccurred(TrialHist)
            s_list = {};
            y_list = {};
        end
    end
    R_prev = R_f;

    % ---- 9. Update solution ----
    U_curr(free_dofs) = U_curr(free_dofs) + alpha * dU_f;
end

% Failed to converge within MaxIterations
U_out    = U_curr;
reaction = [];
end


% ======================================================================
% LOCAL HELPER — plastic yield detector
% ======================================================================
function flag = newPlasticYieldOccurred(obj, TrialHist)
% Returns true if any element gained a new plastic point this iteration.
% Compares committed history (Elements) against the trial history.
flag = false;
if ~obj.Options.ResetOnPlastic || isempty(TrialHist)
    return;
end
for e = 1:numel(obj.Elements)
    el = obj.Elements{e};
    if ~isprop(el, 'HistoryData') || isempty(el.HistoryData)
        continue;
    end
    committed = el.HistoryData;
    trial     = TrialHist{e};
    if isempty(trial), continue; end
    for k = 1:numel(committed)
        if trial(k).p > committed(k).p + 1e-12
            flag = true;
            return;
        end
    end
end
end
