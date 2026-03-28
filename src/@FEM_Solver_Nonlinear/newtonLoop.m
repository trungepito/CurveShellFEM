function [converged, U_out, reaction, iter] = newtonLoop(obj, F_external, U_curr, fixed_dofs)
% NEWTONLOOP - Core iterative solver for any nonlinear problem.
%
% v3.0: Standardized robust implementation.
% - Relative tolerance: ||R|| / ||F_ext|| <= 1e-6
% - Residual convention: R = F_int - F_external
% - Trial-Commit: Stores TrialHist and commits only on convergence.

nDofs = length(U_curr);
free_dofs = setdiff(1:nDofs, fixed_dofs);
tol = 1e-6; % Relative tolerance per v3.0 standard
if isprop(obj, 'Options') && isfield(obj.Options, 'Tolerance')
    tol = obj.Options.Tolerance;
end

% Initial force norm for relative scaling
f_ext_norm = norm(F_external(free_dofs));
if f_ext_norm < 1e-12, f_ext_norm = 1.0; end % Protect against zero load

converged = false;
TrialHist = [];

for iter = 1:obj.Options.MaxIterations
    % 1. Get Tangent Stiffness & Internal Force
    % Returns TrialHist for state management (SK-05)
    [Kt, F_int, TrialHist] = obj.assembleTangentSystem(U_curr);

    % 2. Calculate Residual (R = F_int - F_ext)
    R = F_int - F_external;
    err_rel = norm(R(free_dofs)) / f_ext_norm;

    % Check Convergence (Relative)
    if err_rel <= tol
        converged = true;
        U_out = U_curr;
        reaction = F_int(fixed_dofs);
        
        % 3. Commit History (Trial-Commit Pattern)
        obj.commitHistory(TrialHist);
        return;
    end

    % 4. Solve for increment (du = -Kt \ R)
    dU_f = Kt(free_dofs, free_dofs) \ (-R(free_dofs));

    % 5. Update Solution
    U_curr(free_dofs) = U_curr(free_dofs) + dU_f;
end

U_out = U_curr;
reaction = [];
converged = false;
end
