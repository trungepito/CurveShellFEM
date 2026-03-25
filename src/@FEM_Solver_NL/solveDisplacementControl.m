function solveDisplacementControl(obj, controlNodeID, controlDOF, targetDisp, nSteps, maxIter, tol)
% SOLVEDISPLACEMENTCONTROL - Nonlinear solver using enforced displacement.
%
% Standard Newton-Raphson iteration with displacement control. Ideal for 
% structures exhibiting softening or snap-through behavior.
%
% Syntax:
%   solveDisplacementControl(obj, nodeID, dof, target, steps, maxIter, tol)
%
% Inputs:
%   nodeID   - Target node ID [Integer]
%   dof      - Degree of freedom (1-6) [Integer]
%   target   - Final prescribed displacement [Double]
%   steps    - Number of increments [Integer]
%   maxIter  - Maximum iterations per step [Integer]
%   tol      - Convergence tolerance on residual force [Double]

fprintf('[Solver] Starting Displacement-Controlled Non-Linear Analysis...\n');

% 1. Setup
nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 6;

obj.U = zeros(nDofs, 1);
obj.U_Hist = [];
obj.ReactionHist = [];

% Identify the Control DOF index
c_dof = (controlNodeID-1)*6 + controlDOF;

% Identify Fixed BCs (Standard Supports)
fixed_dofs = [];
if ~isempty(obj.Model.BCs)
    fixed_dofs = (obj.Model.BCs.Node-1)*6 + obj.Model.BCs.DOF;
end

% The "Prescribed" set includes BCs AND the Control DOF
% We must ensure the control dof is not in the fixed_dofs list to avoid double counting
fixed_dofs = setdiff(fixed_dofs, c_dof);

all_fixed = [fixed_dofs; c_dof];
free_dofs = setdiff(1:nDofs, all_fixed);

delta_u_step = targetDisp / nSteps;

fprintf('  >> Control Node: %d, DOF: %d, Target: %.4f m\n', controlNodeID, controlDOF, targetDisp);
bisec_flag=false;
nbisec=0;
step=0;
runflag=true;
sum_iter=0;
current_prescribed_val=0; % maybe wrong if multiple load steps are used
% 2. Stepping Loop.
while runflag
    % Increment the displacement at the control node
    if bisec_flag
        try
            obj.U=obj.U_Hist(:,end); % get the previous covergence step
        catch
            obj.U=zeros(nDofs, 1);
        end
        current_prescribed_val= current_prescribed_val-(0.5/nbisec)*delta_u_step;
    elseif nbisec>0
        current_prescribed_val = current_prescribed_val + (0.8/nbisec)*delta_u_step;
        nbisec=nbisec-1; % there is a risk of doing this loop forever!!!
    else
        step=step+1;
        if delta_u_step<0
            current_prescribed_val = min(step * delta_u_step,current_prescribed_val);
        else
            current_prescribed_val = max(step * delta_u_step,current_prescribed_val);
        end
    end

    % Update the Global U vector with this prescribed value immediately
    % (Predictor Step)
    obj.U(c_dof) = current_prescribed_val;

    fprintf('  >> Step %d/%d (Disp: %.4e)\n', step, nSteps, current_prescribed_val);

    % 3. Newton-Raphson Loop
    for iter = 1:maxIter

        % A. Assemble Tangent Stiffness and Internal Forces
        % (Note: This uses the current U, which has the prescribed value)
        [KT, F_int, TrialHist] = obj.assembleTangentSystem();

        % B. Calculate Residual
        R = -F_int;

        % C. Convergence Check (Only on FREE DOFs)
        R_free = R(free_dofs);
        res_norm = norm(R_free);

        if res_norm < tol
            % CONVERGED
            % Commit History (Plasticity)
            obj.commitHistory(TrialHist);
            
            reaction_force = sum(F_int(c_dof));
            fprintf('     Converged at Iter %d. Residual: %.4e | Reaction: %.4e\n', ...
                iter, res_norm, reaction_force);

            % Store History
            obj.U_Hist(:, end+1) = obj.U;
            obj.ReactionHist(end+1) = reaction_force;
            bisec_flag=false;
            break;
        end

        % D. Solve for Correction (Delta U)
        % We partition the system.
        % We want R_free to become 0.
        % We KEEP the control DOF fixed during iterations (correction = 0)

        KT_ff = KT(free_dofs, free_dofs);

        % if rcond(KT_ff) < 1e-16
        %     warning('Singular Matrix in Displacement Control!');
        %     return;
        % end

        du_free = KT_ff \ R_free;

        % Update U (Only free DOFs change)
        obj.U(free_dofs) = obj.U(free_dofs) + du_free;
        % obj.U(c_dof) remains constant during iterations

        if iter == maxIter
            warning('Max iterations reached in Disp Control step.');
            bisec_flag=true;
            nbisec=nbisec+1;
            % nSteps=nSteps+1;
            fprintf(' The %d bisection at the step % d.\n',nbisec,step);
        end
    end
    sum_iter=sum_iter+iter;
    if nbisec>5
        fprintf('The solution is not covergence at the %d step.\n',step)
        break
    end
    if step==nSteps && nbisec==0
        runflag = false; % Exit the loop if all steps are completed
    end
end
fprintf('[Solver] Displacement Control Analysis Complete.Total iteration %d.\n',sum_iter);
end
