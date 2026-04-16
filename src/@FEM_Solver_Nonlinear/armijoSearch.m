function alpha = armijoSearch(obj, U_curr, dU_f, R_curr, F_ext, free_dofs)
% ARMIJOSEARCH  Backtracking line search along the Newton direction.
%
% Finds a step length alpha in (0,1] such that the residual norm satisfies
% the sufficient-decrease (Armijo) condition:
%
%   ||R(U + alpha*dU)||  <=  (1 - c1*alpha) * ||R(U)||
%
% Inputs:
%   U_curr    full displacement vector at current iterate
%   dU_f      Newton step restricted to free_dofs
%   R_curr    full residual vector at U_curr
%   F_ext     full external force vector
%   free_dofs indices of unconstrained DOFs
%
% Output:
%   alpha     accepted step length in (0,1]

opts  = obj.Options;
c1    = opts.ArmijoC1;
alpha = 1.0;
r0    = norm(R_curr(free_dofs));

nDofs = length(U_curr);

for ls = 1 : opts.MaxLineIter

    % Trial point
    U_try                 = U_curr;
    U_try(free_dofs)      = U_curr(free_dofs) + alpha * dU_f;

    % Cheap residual evaluation — no tangent rebuild
        F_int_try = obj.assembleinternalforceONLY(U_try);
        R_try     = F_int_try - F_ext;
        r_try     = norm(R_try(free_dofs));

        % Armijo sufficient-decrease condition
        if r_try <= (1.0 - c1 * alpha) * r0
            if ls > 1
                fprintf(' [Armijo accepted alpha=%.3f after %d bisections] ', alpha, ls-1);
            end
            return;
        end

        % Halve step length and retry
        alpha = alpha * 0.5;
        fprintf(' [Armijo backtracking... alpha=%.3f] ', alpha);
    end

% alpha holds the last tried value (may be very small).
% Caller uses it unconditionally — a tiny step is better than no step.
end
