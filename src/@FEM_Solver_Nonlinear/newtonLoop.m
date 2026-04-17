function [converged, U_out, reaction, iter, TrialHist] = newtonLoop(obj, F_ext, U_curr, fixed_dofs)
% NEWTONLOOP - Core iterative solver for any nonlinear problem.
%
% v3.1: Fixes applied (C2, C3, H3):
%   - Uses ConvergenceMonitor (BUG-P1 fix).
%   - Calls Assembler.tangent instead of obj.assembleTangentSystem.
%   - Returns U_entry (not drifted U_curr) on divergence.
%   - Uses isprop instead of isfield for handle-class Options.
%   - Linesearch returns eta (pure utility, no state mutation).
%   - commitHistory called ONLY on converge path.
%
% Residual convention: R = F_int - F_ext

nDofs = length(U_curr);
free_dofs = setdiff(1:nDofs, fixed_dofs);

% Validate F_ext size
if length(F_ext) ~= nDofs
    error('newtonLoop:sizeMismatch', 'F_ext must be of size %dx1', nDofs);
end

% Save entry state — returned unchanged on diverge (H3 fix)
U_entry = U_curr;

% Initialize monitor (C1)
mon = ConvergenceMonitor();
if isprop(obj, 'Options')
    if isprop(obj.Options, 'Tolerance'), mon.Tolerance = obj.Options.Tolerance; end
    if isprop(obj.Options, 'MaxIterations'), max_iter = obj.Options.MaxIterations; else, max_iter = 10; end
    if isprop(obj.Options, 'NormType'), mon.NormType = obj.Options.NormType; end
    useLineSearch = isprop(obj.Options, 'UseLineSearch') && obj.Options.UseLineSearch;
else
    max_iter = 10;
    useLineSearch = false;
end
mon.reset(F_ext(free_dofs));

converged  = false;
TrialHist  = [];
reaction   = [];
iters      = 0;

for iter = 1:max_iter
    iters = iter;

    % 1. Assemble (pure function — no side effects) (C2)
    [KT, F_int, TrialHist] = Assembler.tangent(U_curr, obj.Elements, obj.SctrMap, nDofs);

    % 2. Residual — R = F_int - F_ext, BC rows zeroed
    % Convention: R = F_int - lambda*F_ext; positive when over-loaded
    R = F_int - F_ext;
    R(fixed_dofs) = 0;

    % 3. Convergence check
    dU_prev = zeros(length(free_dofs), 1);
    if iter > 1, dU_prev = U_curr(free_dofs) - U_entry(free_dofs); end
    if mon.check(R(free_dofs), dU_prev, U_curr(free_dofs), F_ext(free_dofs), iter)
        converged = true;
        break;
    end

    % 4. Solve for increment
    KT_ff = KT(free_dofs, free_dofs);
    if rcond(full(KT_ff)) < 1e-13
        warning('newtonLoop:singular', 'KT is near-singular at iter %d', iter);
        break;
    end
    dU_f = KT_ff \ (-R(free_dofs));

    % 5. Line search (returns eta scalar — does NOT modify obj.U) (C3)
    if useLineSearch
        dU_full = zeros(nDofs, 1);
        dU_full(free_dofs) = dU_f;
        % linesearch returns eta in (0,1]
        eta = obj.linesearch(U_curr, dU_full, R, F_ext, free_dofs);
    else
        eta = 1.0;
    end

    % 6. Update (trial only — not committed to obj.U)
    U_curr(free_dofs) = U_curr(free_dofs) + eta * dU_f;
end

% 7. Commit or discard
    % reaction = F_int(fixed_dofs); % F_int is the one from the LAST assembly
    reaction = F_int(fixed_dofs);
    U_out = U_curr;
else
    % Diverged: discard TrialHist, return clean entry state
    TrialHist = [];  %#ok<NASGU> — allow GC
    U_out = U_entry;
    reaction = [];
end

end
