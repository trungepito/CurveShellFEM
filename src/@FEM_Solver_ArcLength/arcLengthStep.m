function [u, lambda, converged, iters] = arcLengthStep(obj, ...
        funcHandle, constraintFn, u0, lambda0, ...
        arc_length, usePredictor, tol, maxit)
% ARCLENGHTSTEP - One arc-length predictor-corrector increment.
%
% Implements the generalised arc-length algorithm following Crisfield (1981)
% and the reference sample in arc_length_solver.m.  The corrector uses a
% two-system Newton-Raphson:
%
%   KT * du_I  =  fext                 (tangent load direction)
%   KT * du_II = -R                    (equilibrium correction)
%
%   dl = -(g + h'*du_II) / (s + h'*du_I)
%   du = dl * du_I + du_II
%
% where [g, h, s] are returned by the constraint function.
%
% Syntax:
%   [u, lambda, converged, iters] = arcLengthStep(obj, ...
%       funcHandle, constraintFn, u0, lambda0, ...
%       arc_length, usePredictor, tol, maxit)
%
% Inputs:
%   funcHandle    - @(u,lambda,hist,nri) -> [R, KT, fext, hist]
%   constraintFn  - @(u,l,u0,l0,dup,dlp,si) -> [g, h, s]
%   u0, lambda0   - Converged state at start of this step
%   arc_length    - Scalar arc-length radius for this trial
%   usePredictor  - true = compute tangent predictor (Riks/spherical)
%                   false = zero predictor (load/disp control)
%   tol           - Convergence tolerance on residual norm
%   maxit         - Maximum corrector iterations
%
% Outputs:
%   u         - Displacement vector at end of step (or last iterate)
%   lambda    - Load factor at end of step (or last iterate)
%   converged - true if residual criterion satisfied
%   iters     - Number of corrector iterations performed

% ------------------------------------------------------------------
% Initialise iterate at the beginning of the step
% ------------------------------------------------------------------
u      = u0;
lambda = lambda0;
hist   = 0;   % Plasticity history managed inside obj.Elements; dummy here

% ------------------------------------------------------------------
% Evaluate residual, tangent stiffness, and reference external load
% ------------------------------------------------------------------
[R, KT, fext, hist] = funcHandle(u, lambda, hist, 0);

% Reference norm for relative convergence criterion
f_norm = norm(fext);
if f_norm < eps
    f_norm = 1.0;  % Prevent division by zero for zero-load cases
end

% ------------------------------------------------------------------
% PREDICTOR STEP
% Compute the predictor direction (dup, dlp) in the augmented space.
% For load/disp control, dup = 0 and dlp = 0 (the constraint already
% fixes the direction; no additional scaling is needed).
% ------------------------------------------------------------------
dup = zeros(length(u), 1);
dlp = 0;

if usePredictor
    % Riks predictor: find the tangent direction in (u, lambda) space
    % and scale it so the arc-length step size equals arc_length.
    try
        dup = KT \ fext;
    catch ME
        % Singular tangent at the very first step — cannot proceed
        converged = false;
        iters     = 0;
        return;
    end

    % Current stiffness parameter (sign of determinant proxy)
    % Positive -> loading direction; negative -> unloading (snap-back)
    k0 = dot(fext, dup) / (dot(dup, dup) + eps);

    if k0 >= 0
        dlp =  arc_length / (norm(dup) + eps);
    else
        dlp = -arc_length / (norm(dup) + eps);
    end

    % Apply predictor: advance u and lambda
    u      = u0 + dlp * dup;
    lambda = lambda0 + dlp;

    % Re-evaluate residual at the predictor point
    [R, KT, ~, ~] = funcHandle(u, lambda, hist, 0);
end

% ------------------------------------------------------------------
% CORRECTOR LOOP  (augmented Newton-Raphson)
% ------------------------------------------------------------------
converged = false;
iters     = 0;

for i = 1:maxit
    iters = i;

    % Evaluate constraint and its gradients
    [g, h, s] = constraintFn(u, lambda, u0, lambda0, dup, dlp, arc_length);

    % Solve the two right-hand side systems
    % Guard against singular KT by catching the backslash warning
    try
        du_I  =  KT \ fext;    % Tangent load direction
        du_II = -KT \ R;       % Equilibrium correction
    catch ME
        % Singular stiffness — this trial step cannot converge
        converged = false;
        return;
    end

    % Load factor increment from constraint equation
    denom = s + h' * du_I;
    if abs(denom) < eps * max(abs(s), 1)
        % Near-zero denominator: constraint is degenerate for this trial
        converged = false;
        return;
    end

    dl = -(g + h' * du_II) / denom;

    % Full displacement and load-factor update
    du     = dl * du_I + du_II;
    lambda = lambda + dl;
    u      = u + du;

    % Re-assemble at the new iterate
    [R, KT, ~, ~] = funcHandle(u, lambda, hist, 0);

    % Convergence check: scaled residual norm
    R_norm = norm(R);
    if R_norm <= tol * f_norm
        converged = true;
        break;
    end
end

% Inform the caller whether we converged
if ~converged
    % Return the last iterate so the caller can decide to retry
    % (solveArcLengthStage rolls back to u0, lambda0 on failure)
end
end
