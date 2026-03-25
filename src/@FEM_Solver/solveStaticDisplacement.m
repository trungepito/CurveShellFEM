function solveStaticDisplacement(obj)
fprintf('[Solver] Assembling Stiffness Matrix...\n');
obj.assembleK();
fprintf('[Solver] Applying Loads and BCs...\n');
obj.applyLoads();
% obj.applyConstraints();
% Apply Constraints (Identity/Penalty Method)

fprintf('[Solver] Solving Linear System...\n');
nDofs = size(obj.GlobalF,1);
fixed_dofs = [];
fixed_vals = [];

% Convert BC list to indices
if ~isempty(obj.Model.BCs)
    if istable(obj.Model.BCs)
        % Table format (Modern: Node, DOF, Value, Tag)
        fixed_dofs = (obj.Model.BCs.Node-1)*6 + obj.Model.BCs.DOF;
        fixed_vals = obj.Model.BCs.Value;
    else
        % Matrix format
        if size(obj.Model.BCs, 2) >= 3
            % [Node, DOF, Value]
            fixed_dofs = (obj.Model.BCs(:,1)-1)*6 + obj.Model.BCs(:,2);
            fixed_vals = obj.Model.BCs(:,3);
        else
            % [Node, DOF] (Implies Value=0)
            fixed_dofs = (obj.Model.BCs(:,1)-1)*6 + obj.Model.BCs(:,2);
            fixed_vals = zeros(length(fixed_dofs), 1);
        end
    end
end

free_dofs = setdiff(1:nDofs, fixed_dofs);

% 3. Partition and Solve
% U_free = K_ff \ (F_free - K_fc * U_fixed)
U_full = zeros(nDofs, 1);
U_full(fixed_dofs) = fixed_vals;
F_effective = obj.GlobalF(free_dofs) - obj.GlobalK (free_dofs, fixed_dofs) * fixed_vals(:);
U_calc = obj.GlobalK(free_dofs, free_dofs) \ F_effective;
U_full(free_dofs) = U_calc;

obj.U = U_full;

fprintf('[Solver] Static Solution Complete.\n');
end