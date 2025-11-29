function solveNonLinear(obj, numLoadSteps, maxIter, tol)
fprintf('[Solver] Starting Non-Linear Newton-Raphson Solution...\n');

% 1. Setup
nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 5;

% Initialize State
obj.U = zeros(nDofs, 1); % Total Displacement
total_load_vector = zeros(nDofs, 1);

% Build Total Load Vector
loads = obj.Model.Loads;
for i = 1:size(loads, 1)
    idx = (loads(i,1)-1)*5 + loads(i,2);
    total_load_vector(idx) = total_load_vector(idx) + loads(i,3);
end

% Identify Free and Fixed DOFs
fixed_dofs = [];
if ~isempty(obj.Model.BCs)
    fixed_dofs = (obj.Model.BCs(:,1)-1)*5 + obj.Model.BCs(:,2);
end
free_dofs = setdiff(1:nDofs, fixed_dofs);

% 2. Load Stepping Loop
for step = 1:numLoadSteps
    lambda = step / numLoadSteps;
    F_ext_current = total_load_vector * lambda;

    fprintf('  >> Step %d/%d (Load Factor: %.2f)\n', step, numLoadSteps, lambda);

    % 3. Newton-Raphson Iteration Loop
    for iter = 1:maxIter

        % A. Assemble Tangent Stiffness and Internal Force
        [KT_global, F_int_global] = obj.assembleTangentSystem();

        % B. Calculate Residual (R = F_ext - F_int)
        Residual = F_ext_current - F_int_global;

        % Check Convergence (Force Norm on free DOFs)
        res_norm = norm(Residual(free_dofs));
        if res_norm < tol
            fprintf('     Converged at Iter %d. Residual: %e\n', iter, res_norm);
            break;
        end

        % C. Solve for correction (du = KT \ R)
        % Partition matrices
        KT_red = KT_global(free_dofs, free_dofs);
        R_red = Residual(free_dofs);

        if rcond(KT_red) < 1e-15
            warning('Near singular stiffness matrix. Buckling or Mechanism detected.');
        end

        du_red = KT_red \ R_red;

        % D. Update Total Displacement
        obj.U(free_dofs) = obj.U(free_dofs) + du_red;

        if iter == maxIter
            warning('     Max iterations reached without convergence!');
        end
    end
end

fprintf('[Solver] Non-Linear Solution Complete.\n');
end