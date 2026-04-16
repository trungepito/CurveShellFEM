function [p_free, accept] = lbfgsDirection(s_list, y_list, g_free, opts)
% LBFGSDIRECTION  Limited-memory BFGS direction via two-loop recursion.
%
% Computes the L-BFGS approximate inverse-Hessian times gradient:
%   p_free = H_m^{-1} * g_free
%
% The Newton step is then  dU_f = -p_free.
%
% Reference: Nocedal & Wright, "Numerical Optimization", 2nd ed.,
%            Algorithm 7.4 (two-loop recursion), p. 178.
%
% All vectors are restricted to free_dofs — they are NEVER stored as
% full nDofs vectors.  This prevents dimension mismatches when the
% free-DOF set changes between loading stages.
%
% Inputs:
%   s_list   cell of displacement increments  s_k = alpha_k * dU_{f,k}
%   y_list   cell of residual increments      y_k = R_{f,k} - R_{f,k-1}
%   g_free   current residual on free DOFs    g = R_f
%   opts     SolverOptions instance
%
% Outputs:
%   p_free   H^{-1} * g  (descent direction is -p_free)
%   accept   false if any curvature condition fails; caller should reset
%            history and fall back to a full Newton step
%
% See also: SolverOptions, FEM_Solver_Nonlinear/newtonLoop

m      = numel(s_list);
accept = true;

% No history yet — return gradient (equivalent to identity Hessian)
if m == 0
    p_free = g_free;
    return;
end

% ------------------------------------------------------------------
% Validate curvature conditions before the recursion
% ------------------------------------------------------------------
rho = zeros(m, 1);
for i = 1 : m
    ys = y_list{i}' * s_list{i};
    if ys < opts.LBFGSCurvEps
        % Non-positive curvature — pair is invalid; signal reset
        accept = false;
        p_free = g_free;
        return;
    end
    rho(i) = 1.0 / ys;
end

% ------------------------------------------------------------------
% Two-loop recursion
% ------------------------------------------------------------------
q     = g_free;
alpha = zeros(m, 1);

% Forward pass: most recent pair is index m
for i = m : -1 : 1
    alpha(i) = rho(i) * (s_list{i}' * q);
    q        = q - alpha(i) * y_list{i};
end

% Initial Hessian scaling using the most recent accepted pair
% H_0 = gamma * I,  gamma = (s_m' y_m) / (y_m' y_m)
gamma = (s_list{m}' * y_list{m}) / (y_list{m}' * y_list{m});
r     = gamma * q;

% Backward pass
for i = 1 : m
    beta = rho(i) * (y_list{i}' * r);
    r    = r + s_list{i} * (alpha(i) - beta);
end

p_free = r;
end
