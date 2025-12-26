function solveNonLinear(obj,SolNLopt)
fprintf('[Solver] Starting Non-Linear Newton-Raphson Solution...\n');

numLoadSteps=SolNLopt.numLoadSteps;
maxIter=SolNLopt.maxIter;
tol=SolNLopt.tol;
% 1. Setup
nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 6;

% Initialize State
% obj.U = zeros(nDofs, 1);
obj.LambdaHist = [];
obj.U_Hist = [];
obj.StrainEnergy = [];
obj.U = zeros(nDofs, 1); % Total Displacement
total_load_vector = zeros(nDofs, 1);

% Build Total Load Vector
loads = obj.Model.Loads;
for i = 1:size(loads, 1)
    idx = (loads(i,1)-1)*6 + loads(i,2);
    total_load_vector(idx) = total_load_vector(idx) + loads(i,3);
end

% Identify Free and Fixed DOFs
% fixed_dofs = [];
fixed_dofs = [];
if ~isempty(obj.Model.BCs)
    fixed_dofs = (obj.Model.BCs(:,1)-1)*6 + obj.Model.BCs(:,2);
end
free_dofs = setdiff(1:nDofs, fixed_dofs);
% free_dofs = setdiff(1:nDofs, fixed_dofs);
current_energy = 0;
% 2. Load Stepping Loop
for step = 1:numLoadSteps
    lambda = step/numLoadSteps;
    F_ext_current = total_load_vector * lambda;

    fprintf('  >> Step %d/%d (Load Factor: %.2f)\n', step, numLoadSteps, lambda);

    % 3. Newton-Raphson Iteration Loop
    for iter = 1:maxIter
        % fprintf(' Interation %d\n',iter);
        % A. Assemble Tangent Stiffness and Internal Force
        [KT_global, F_int_global] = obj.assembleTangentSystem();

        % B. Calculate Residual (R = F_ext - F_int)
        Residual = F_ext_current - F_int_global;

        % Check Convergence (Force Norm on free DOFs)
        % res_norm = norm(Residual(free_dofs));
        % C. CONVERGENCE CHECKS

        % 1. Force Norm (Translation DOFs: 1,2,3)
        trans_indices = [1:6:nDofs, 2:6:nDofs, 3:6:nDofs];
        trans_indices = intersect(trans_indices, free_dofs);
        norm_R_force = norm(Residual(trans_indices));

        % 2. Moment Norm (Rotation DOFs: 4,5,6)
        rot_indices = [4:6:nDofs, 5:6:nDofs, 6:6:nDofs];
        rot_indices = intersect(rot_indices, free_dofs);
        norm_R_mom = norm(Residual(rot_indices));

        % 3. Check
        isConverged = (norm_R_force < tol) && (norm_R_mom < tol*100);
        % (Moments often have different scaling, allow relaxed tol)

        if isConverged
            if iter == 1
                fprintf('     Step converged immediately (Linear behavior).\n');
            else
                fprintf('     Converged at Iter %d. |R_force|: %.4e, |R_mom|: %.4e\n', ...
                    iter, norm_R_force, norm_R_mom);
            end

            % Save History
            obj.LambdaHist(end+1) = lambda;
            obj.U_Hist(:, end+1) = obj.U;

            % Approximate Strain Energy (Trapezoidal Rule for current step)
            % W = W_prev + 0.5 * dU * (F_prev + F_curr)
            % Simplified: Work of External Forces
            current_energy = dot(obj.U, F_ext_current);
            obj.StrainEnergy(end+1) = current_energy;
            break;
        end


        % C. Solve for correction (du = KT \ R)
        % Partition matrices
        % Partition matrices
        KT_red = KT_global(free_dofs, free_dofs);
        R_red = Residual(free_dofs);

        % if condest(KT_red) < 1e-12
        %     warning('Near singular stiffness matrix. Buckling or Mechanism detected.');
        % end

        du_red = KT_red \ R_red;
        dU = zeros(nDofs, 1);
        dU(free_dofs) = du_red;
        if SolNLopt.linesearch
        obj.linesearch(obj.U,dU,Residual,F_ext_current,free_dofs)
        else
        obj.U(free_dofs) = obj.U(free_dofs) + du_red; % here or after the check is better?
        end
        % Energy Increment Check (Criterion 3)
        work_increment = abs(dot(dU, Residual));
        if (work_increment < tol * 1e-3 * current_energy) && (iter > 1) && (current_energy > 1e-9)
            fprintf('     Converged by Energy Criterion at Inter %d. Work Inc: %.4e\n', iter, work_increment);
            obj.LambdaHist(end+1) = lambda;
            obj.U_Hist(:, end+1) = obj.U;
            obj.StrainEnergy(end+1) = dot(obj.U, F_ext_current);
            break;
        end
        % D. Update Total Displacement
        % obj.U(free_dofs) = obj.U(free_dofs) + du_red;

        if iter == maxIter
            warning('     Max iterations reached without convergence!');
        end
    end
end

fprintf('[Solver] Non-Linear Solution Complete.\n');
end