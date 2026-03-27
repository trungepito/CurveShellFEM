function [converged, U_out, reaction, iter] = newtonLoop(obj, F_external, U_curr, fixed_dofs)
    % NEWTONLOOP - Core iterative solver for any nonlinear problem.
    nDofs = length(U_curr);
    free_dofs = setdiff(1:nDofs, fixed_dofs);

    for iter = 1:obj.Options.MaxIterations
        % 1. Get Tangent Stiffness & Internal Force
        [Kt, F_int] = obj.assembleTangentSystem(U_curr);

        % 2. Calculate Residual
        R = F_external - F_int;
        err = norm(R(free_dofs));

        % Check Convergence
        if err < obj.Options.Tolerance
            converged = true;
            U_out = U_curr;
            reaction = F_int(fixed_dofs);
            return;
        end

        % 3. Solve for increment
        dU_f = Kt(free_dofs, free_dofs) \ R(free_dofs);

        % 4. Update Solution
        U_curr(free_dofs) = U_curr(free_dofs) + dU_f;
    end

    U_out = U_curr;
    reaction = [];
    converged = false;
end
