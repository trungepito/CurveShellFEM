function [g, h, s] = crisfieldConstraint(obj, u, lambda, ...
        u0, lambda0, dup, dlp, arc_length)
% CRISFIELDCONSTRAINT  Riks / spherical arc-length constraint.
%
% Enhancement log (P1.3, P3.1):
%   P1.3 — The scalar  s = psi^2 * dlp  was used as the full denominator
%           guard.  When dlp = 0 the fallback was arc_length * psi^2, which
%           is wrong when F_ext is not O(1).  The guard is now delegated
%           entirely to arcLengthStep, which tests the *full* denominator
%           (s + h'*du_I) with a relative threshold.  This function just
%           returns s correctly; it no longer sets s to a fallback value.
%
%   P3.1 — The load-direction scale now uses  psi * ||F_ext||  so that the
%           arc-length metric is dimensionally consistent:
%
%               ds^2 = ||u - u1||^2 + (psi * ||F_ext||)^2 * (lambda - lambda1)^2
%
%           With psi = 0 this reduces to the pure cylindrical constraint
%           (Ramm 1981).  With psi = 1 and ||F_ext|| = 1 this recovers the
%           original Crisfield (1981) formulation.  The caller passes
%           arc_length as the step size  ds.
%
% Convention:
%   u1 = u0 + dlp * dup   (predictor end-point in displacement space)
%   l1 = lambda0 + dlp    (predictor end-point in load space)
%   g  = constraint value  (= 0 at equilibrium on the arc)
%   h  = dg/du  (gradient w.r.t. displacements, on free DOFs)
%   s  = dg/dlambda

% Scale the load direction by ||F_ext|| to make the metric dimensionally
% homogeneous.  f_scale is the Euclidean norm of the reference load vector
% stored on the solver; fall back to 1 if not yet set.
if isprop(obj, 'F_ext_start') && norm(obj.F_ext_start) > 0
    f_scale = norm(obj.F_ext_start);
else
    f_scale = 1.0;
end
psi_eff = obj.ArcLengthPsi * f_scale;   % effective load-direction scale

% Predictor end-point on the constraint surface
u1      = u0 + dlp * dup;
lambda1 = lambda0 + dlp;

% Constraint: hyperplane normal to predictor through (u1, lambda1)
%   g = dup'*(u - u1) + psi_eff^2 * dlp * (lambda - lambda1) = 0
g = dup' * (u - u1) + psi_eff^2 * dlp * (lambda - lambda1);
h = dup;                        % dg/du  (same dimension as u)
s = psi_eff^2 * dlp;            % dg/dlambda

% NOTE: the denominator guard  abs(s + h'*du_I) < threshold  is handled
% entirely in arcLengthStep so that the full sum is tested.  We do NOT
% override s here; a near-zero s is a legitimate physical state (limit
% point or pure displacement control), and the corrector handles it.

end
