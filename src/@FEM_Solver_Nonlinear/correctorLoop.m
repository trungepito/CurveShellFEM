function [u_out, l_out, F_int_out, TrialHist_out, converged, iters_used] = ...
    correctorLoop(obj, u0, l0, strategy, ds, assembleForArcLength, ...
    free_dofs, fixed_dofs, u_pred, l_pred, dup_step, dlp, F_ext_total, mon, opts)
% CORRECTORLOOP  Pure Newton corrector with no side effects.
%   Performs Newton iteration from predictor state (u_pred, l_pred) to 
%   convergence using hybrid Newton/L-BFGS with optional line search.
%
%   Returns: converged state WITHOUT calling commitHistory, notify, or 
%           writing to obj.state. Only updates obj.lbfgs_S/Y history internally.
%
% OUTPUT:
%   u_out, l_out     - Converged displacement and load factor
%   F_int_out        - Final internal force vector (full)
%   TrialHist_out    - Final trial history (e.g., Gaussian point data)
%   converged        - Boolean: true if converged within MaxIterations
%   iters_used       - Number of iterations performed

opts_maxit = opts.MaxIterations;
opts_UseLBFGS = opts.UseLBFGS;
opts_UseLineSearch = opts.UseLineSearch;
opts_LineSearchMethod = opts.LineSearchMethod;
opts_LBFGSHistory = opts.LBFGSHistory;

% Initialize trial state from predictor
u_trial = u_pred;
lambda_trial = l_pred;
rebuild_tangent = true;

% Initialize outputs
u_out = u_pred;
l_out = l_pred;
F_int_out = zeros(length(u_pred), 1);
TrialHist_out = [];
converged = false;
iters_used = 0;

nDofs = length(u_pred);
incremental_dU_f = u_pred(free_dofs) - u0(free_dofs);

for i = 1:opts_maxit
    iters_used = i;

    % 1. Constraint evaluation at current trial state
    [g, h_raw, s_val] = strategy.constraint(...
        u_trial(free_dofs), lambda_trial, ...
        u0(free_dofs), l0, ...
        dup_step(free_dofs), dlp, ds);

    % 2. Assembly and residual (with tangent rebuild logic)
    if rebuild_tangent
        [KT, F_int_loc, TrialHist_trial] = Assembler.tangent(...
            u_trial, obj.Elements, obj.SctrMap, nDofs);
        R = F_int_loc - lambda_trial * F_ext_total;
        R(fixed_dofs) = 0;
        KT_ff = KT(free_dofs, free_dofs);
        L_KT  = decomposition(KT_ff, 'auto');
        rebuild_tangent = false;
    else
        % Cheap residual update (only F_int), no tangent rebuild
        F_int_loc = obj.assembleinternalforceONLY(u_trial);
        R = F_int_loc - lambda_trial * F_ext_total;
        R(fixed_dofs) = 0;
    end
    
    R_f    = R(free_dofs);
    fext_f = F_ext_total(free_dofs);

    % 3. Convergence check (with monitor)
    if mon.check(R_f, incremental_dU_f, u_trial(free_dofs), fext_f, i)
        converged = true;
        u_out = u_trial;
        l_out = lambda_trial;
        F_int_out = R + lambda_trial * F_ext_total;
        TrialHist_out = TrialHist_trial;
        break;
    end
    
    % 4. Check monitor recommendations (cutback/abort/linesearch)
    action = mon.recommend();
    if strcmp(action, 'abort') || strcmp(action, 'cutback')
        converged = false;
        break;
    end

    % 5. Solve for Newton directions (Hybrid Newton / L-BFGS)
    use_quasi = opts_UseLBFGS && i > 1 && ~isempty(obj.lbfgs_S);
    accept_lbfgs = false;
    
    if use_quasi
        [p_I,  acc_I]  = obj.lbfgsDirection(obj.lbfgs_S, obj.lbfgs_Y, -fext_f);
        [p_II, acc_II] = obj.lbfgsDirection(obj.lbfgs_S, obj.lbfgs_Y, R_f);
        if acc_I && acc_II
            du_I_f = -p_I;
            du_II_f = -p_II;
            accept_lbfgs = true;
        end
    end
    
    if ~accept_lbfgs
        % Fallback: True Newton with periodic rebuild
        if i > 7
            rebuild_tangent = true;
            continue;
        end
        du_I_f  =  L_KT \ fext_f;
        du_II_f = -(L_KT \ R_f);
    end

    % 6. Compute step correction
    h_f = zeros(length(free_dofs), 1);
    if ~isempty(h_raw)
        h_f = h_raw;
    end

    denom = s_val + h_f' * du_I_f;
    if abs(denom) < 1e-14 * (abs(s_val) + 1)
        converged = false;
        break;
    end

    dl = -(g + h_f' * du_II_f) / denom;
    du_f = dl * du_I_f + du_II_f;

    % 7. Line search (if requested by monitor or by options)
    eta = 1.0;
    if strcmp(action, 'linesearch') || opts_UseLineSearch
        if strcmp(opts_LineSearchMethod, 'armijo')
            eta = obj.armijoSearch(u_trial, du_f, R, F_ext_total, free_dofs);
        else
            eta = obj.linesearch(u_trial, du_f, R, F_ext_total, free_dofs);
        end
    end
    
    % 8. Apply update and manage L-BFGS history
    du_eff_f = eta * du_f;
    incremental_dU_f = du_eff_f;
    
    u_trial_next = u_trial;
    u_trial_next(free_dofs) = u_trial(free_dofs) + du_eff_f;
    lambda_trial_next = lambda_trial + dl;
    
    % Update L-BFGS pairs if enabled
    if opts_UseLBFGS
        F_int_next = obj.assembleinternalforceONLY(u_trial_next);
        R_next = F_int_next - lambda_trial_next * F_ext_total;
        y_i = R_next(free_dofs) - R_f;
        
        obj.lbfgs_S{end+1} = du_eff_f;
        obj.lbfgs_Y{end+1} = y_i;
        if numel(obj.lbfgs_S) > opts_LBFGSHistory
            obj.lbfgs_S(1) = [];
            obj.lbfgs_Y(1) = [];
        end
    end
    
    % 9. Advance to next iteration
    u_trial = u_trial_next;
    lambda_trial = lambda_trial_next;
end

% Final return values
u_out = u_trial;
l_out = lambda_trial;
F_int_out = R + lambda_trial * F_ext_total;
if iters_used <= opts_maxit
    TrialHist_out = TrialHist_trial;
end

end
