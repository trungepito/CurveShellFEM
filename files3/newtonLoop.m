function [converged, U_out, reaction, iter] = newtonLoop(obj, F_external, U_curr, fixed_dofs)
% NEWTONLOOP - Core iterative solver for any nonlinear problem.
%
% Enhancement log (P2.2):
%   KT symmetry enforcement moved to assembleTangentSystem, which now
%   applies  KT = 0.5*(KT + KT')  after every element assembly.  This
%   function therefore no longer needs to symmetrise explicitly; the
%   comment below documents the intended convention so it is not
%   re-introduced here by accident.
%
%   Convergence criterion: relative force norm
%       ||R(free)|| / ||F_ext(free)|| <= tol
%   where  R = F_int - F_ext  (P1.2 sign convention, consistent with
%   the arc-length corrector).

nDofs      = length(U_curr);
free_dofs  = setdiff(1:nDofs, fixed_dofs);
tol        = 1e-6;
if isprop(obj, 'Options') && isfield(obj.Options, 'Tolerance')
    tol = obj.Options.Tolerance;
end

f_ext_norm = norm(F_external(free_dofs));
if f_ext_norm < 1e-12, f_ext_norm = 1.0; end

converged  = false;
TrialHist  = [];

for iter = 1 : obj.Options.MaxIterations

    % P2.2: KT symmetry is enforced inside assembleTangentSystem.
    % The returned KT is already 0.5*(KT+KT'); no re-symmetrisation here.
    [Kt, F_int, TrialHist] = obj.assembleTangentSystem(U_curr);

    % Residual convention: R = F_int - F_ext  (positive = away from equilibrium)
    R       = F_int - F_external;
    err_rel = norm(R(free_dofs)) / f_ext_norm;

    if err_rel <= tol
        converged = true;
        U_out     = U_curr;
        reaction  = F_int(fixed_dofs);
        obj.commitHistory(TrialHist);
        return;
    end

    % Newton direction: KT * dU = -R  (P1.2: toward equilibrium)
    dU_f = Kt(free_dofs, free_dofs) \ (-R(free_dofs));
    U_curr(free_dofs) = U_curr(free_dofs) + dU_f;
end

U_out     = U_curr;
reaction  = [];
converged = false;
end
