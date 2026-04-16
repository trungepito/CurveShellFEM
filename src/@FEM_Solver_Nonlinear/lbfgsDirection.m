function [p_free, accept] = lbfgsDirection(obj, s_list, y_list, g_free)
% LBFGSDIRECTION  Limited-memory BFGS direction via two-loop recursion.
%
% Computes: p_free = H_m^{-1} * g_free
%
% All vectors are restricted to free_dofs.
%
% Inputs:
%   s_list   cell of displacement increments  s_k = alpha_k * dU_{f,k}
%   y_list   cell of residual increments      y_k = R_{f,k} - R_{f,k-1}
%   g_free   current residual on free DOFs    g = R_f
%
% Outputs:
%   p_free   H^{-1} * g  (descent direction is -p_free)
%   accept   false if any curvature condition fails

m      = numel(s_list);
accept = true;
opts   = obj.Options;

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
        % Non-positive curvature — signal reset
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
% gamma = (s_m' y_m) / (y_m' y_m)
gamma = (s_list{m}' * y_list{m}) / (y_list{m}' * y_list{m});
r     = gamma * q;

% Backward pass
for i = 1 : m
    beta = rho(i) * (y_list{i}' * r);
    r    = r + s_list{i} * (alpha(i) - beta);
end

p_free = r;
end
