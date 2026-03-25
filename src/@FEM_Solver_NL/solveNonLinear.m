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
% Build Total Load Vector
obj.applyLoads();
total_load_vector = obj.GlobalF;

% Identify Free and Fixed DOFs
obj.applyConstraints();
free_dofs = obj.FreeDofs;

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
        
        fprintf('     Iter %d | |R_force|: %.4e, |R_mom|: %.4e\n', ...
                    iter, norm_R_force, norm_R_mom);

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
        
        fprintf('     Iter %d | |R|: %.4e | |du|: %.4e | |U|: %.4e\n', ...
                    iter, norm_R_force+norm_R_mom, norm(du_red), norm(obj.U));
        
        if SolNLopt.linesearch
            obj.linesearch(obj.U,dU,Residual,F_ext_current,free_dofs)
        else
            obj.U(free_dofs) = obj.U(free_dofs) + du_red; 
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