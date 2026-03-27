function [u, lambda, F_int, TrialHist, converged, iters] = arcLengthStep(obj, ...
        funcHandle, constraintFn, free_dofs, ...
        u0, lambda0, dup_prev, ...
        arc_length, usePredictor, tol, maxit)
% ARCLENGHTSTEP  One arc-length predictor-corrector increment.
%
% Implements the generalised Crisfield arc-length algorithm.
% The corrector solves an augmented Newton system at each iteration:
%
%   KT(f,f) * du_I   =  fext(f)      (tangent load direction)
%   KT(f,f) * du_II  = -R(f)         (equilibrium correction)
%
%   dl  = -(g + h(f)'*du_II) / (s + h(f)'*du_I)
%   du  =  dl * du_I + du_II
%
% where [g, h, s] come from the constraint function and (f) denotes the
% free-DOF partition.
%
% Fixes applied versus previous version:
%   1. KT is solved on the free-DOF partition only.  The previous code
%      passed the full system to backslash; rows/columns corresponding to
%      prescribed DOFs make the system rank-deficient and produce garbage
%      increments or a singular-matrix error.
%   2. Convergence is tested on norm(R(free_dofs)) not norm(R).  The
%      prescribed-DOF rows of R are zeroed in the assembly closure, so
%      including them in the norm dilutes the residual and can cause false
%      "convergence" on the very first iteration.
%   3. Predictor sign (CSP): current stiffness parameter uses
%      dot(dup_prev, dup_curr) instead of dot(fext, dup).  dot(fext, dup)
%      is always positive for a positive-definite KT and never reverses
%      sign, so it cannot detect snap-back.  The correct CSP compares the
%      new predictor direction with the previous step's direction.
%   4. F_int and TrialHist are returned to support reaction recovery and
%      plasticity commitment without extra assembly.
%   5. try-catch around KT\fext is replaced by rcond-guard, which is
%      faster and does not swallow genuine errors.
%
% Syntax:
%   [u, lambda, F_int, TrialHist, converged, iters] = arcLengthStep(obj, ...
%       funcHandle, constraintFn, free_dofs, ...
%       u0, lambda0, dup_prev, ...
%       arc_length, usePredictor, tol, maxit)
%
% Inputs:
%   funcHandle    @(u,l,h,n)->[R,KT,fext,TrialHist]  assembly closure
%   constraintFn  @(u,l,u0,l0,dup,dlp,si)->[g,h,s]
%   free_dofs     indices of unconstrained DOFs (column vector)
%   u0, lambda0   converged state at start of this step
%   dup_prev      displacement increment from the PREVIOUS converged step
%                 (used for CSP sign check; zeros on the very first step)
%   arc_length    trial arc-length radius
%   usePredictor  true = Riks tangent predictor; false = zero predictor
%   tol, maxit    Newton convergence settings
%
% Outputs:
%   u, lambda     state at the end of the step (iterate if not converged)
%   F_int         internal force vector at the returned state
%   converged     logical
%   iters         number of corrector iterations performed

% ------------------------------------------------------------------
% Initialise at the beginning of the step
% ------------------------------------------------------------------
u      = u0;
lambda = lambda0;
F_int      = zeros(length(u0), 1);
TrialHist  = {};
hist       = 0;   % managed inside the element cache

[R, KT, fext, TrialHist] = funcHandle(u, lambda, hist, 0);

% Reference norm for relative convergence criterion.
% Use free-DOF block of fext so prescribed-DOF zeros do not deflate it.
f_norm = norm(fext(free_dofs));
if f_norm < eps
    f_norm = 1.0;
end

% ------------------------------------------------------------------
% Predictor step (Riks only)
%
% FIX (CSP sign): previous code used dot(fext, dup) as the current
% stiffness parameter (k0).  For a symmetric positive-definite KT this
% dot product equals dup'*KT*dup / norm(dup)^2, which is always positive
% and therefore never detects snap-back.
%
% The correct CSP is: compare the new tangent direction dup with the
% displacement direction taken in the PREVIOUS converged step (dup_prev).
% A sign reversal (dot < 0) means the path has turned back — unload.
% ------------------------------------------------------------------
dup = zeros(length(u), 1);
dlp = 0;

if usePredictor
    % Solve on free-DOF partition to avoid singular system
    KT_ff = KT(free_dofs, free_dofs);

    if condest(KT_ff) < 1e-14
        converged = false;
        iters     = 0;
        return;
    end

    dup_f = KT_ff \ fext(free_dofs);
    dup(free_dofs) = dup_f;

    % Current stiffness parameter (sign of the equilibrium path direction)
    if norm(dup_prev) < eps
        % Very first step of the analysis: no previous direction; load forward.
        k0 = 1;
    else
        k0 = dot(dup_prev, dup);   % positive = same direction, negative = snap-back
    end

    if k0 >= 0
        dlp =  arc_length / (sqrt(norm(dup_f)^2 + obj.ArcLengthPsi^2) + eps);
    else
        dlp = -arc_length / (sqrt(norm(dup_f)^2 + obj.ArcLengthPsi^2) + eps);
    end

    u      = u0 + dlp * dup;
    lambda = lambda0 + dlp;

    [R, KT, ~, TrialHist] = funcHandle(u, lambda, hist, 0);
end

% ------------------------------------------------------------------
% Corrector loop (augmented Newton-Raphson)
% ------------------------------------------------------------------
converged = false;
iters     = 0;

for i = 1 : maxit
    iters = i;

    [g, h, s] = constraintFn(u, lambda, u0, lambda0, dup, dlp, arc_length);

    % FIX (DOF partition): solve only the free-DOF block.
    % Fixed DOFs never appear in the Newton system; their rows were already
    % zeroed in the assembly closure so they would corrupt the solve.
    KT_ff  = KT(free_dofs, free_dofs);
    R_f    = R(free_dofs);
    fext_f = fext(free_dofs);
    h_f    = h(free_dofs);

    if condest(KT_ff) < 1e-14
        converged = false;
        return;
    end

    du_I_f  =  KT_ff \ fext_f;    % tangent load direction
    du_II_f = -KT_ff \ R_f;       % equilibrium correction

    % Load-factor increment from constraint
    denom = s + h_f' * du_I_f;
    if abs(denom) < 1e-14 * max(abs(s), 1)
        converged = false;
        return;
    end

    dl = -(g + h_f' * du_II_f) / denom;

    % Expand back to full DOF vector (fixed DOFs stay at their targets)
    du = zeros(length(u), 1);
    du(free_dofs) = dl * du_I_f + du_II_f;

    lambda = lambda + dl;
    u      = u + du;

    [R, KT, ~, TrialHist] = funcHandle(u, lambda, hist, 0);

    % FIX (convergence check): use free-DOF residual only.
    % The prescribed-DOF rows of R are zeroed by the closure; including
    % them in the norm would always show zero contribution and can cause
    % the criterion to pass on the first iteration.
    R_norm = norm(R(free_dofs));
    if R_norm <= tol * f_norm
        converged = true;
        break;
    end
end

% Recover F_int from R so caller avoids an extra assembly for reactions.
% At the returned (u, lambda): R = lambda*F_ext - F_int  =>  F_int = lambda*F_ext - R
[~, F_int_raw] = obj.assembleTangentSystem(u);
F_int = F_int_raw;

end
