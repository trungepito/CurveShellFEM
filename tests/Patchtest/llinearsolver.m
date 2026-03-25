% Add to FEM_Solver.m
function U_full=llinearsolver(Ke,BCs)
    fprintf('[Solver] Solving Linear Static System...\n');
    % 1. Assemble
    % [K, F] = obj.assembleTangentSystem(); % Or separate linear assembly
    
    % 2. Process BCs (Assume Model.BCs stores [Node, DOF, Value])
    nDofs = size(Ke,1);
    F=zeros(nDofs,1);

    fixed_dofs = [];
    fixed_vals = [];
    
    % Convert BC list to indices
    if ~isempty(BCs)
        if size(BCs,2) == 3 
            % Format: [Node, DOF, Value]
            for i = 1:size(BCs, 1)
                idx = (BCs(i,1)-1)*6 + BCs(i,2);
                fixed_dofs(end+1) = idx;
                fixed_vals(end+1) = BCs(i,3);
            end
        end
    end
    
    free_dofs = setdiff(1:nDofs, fixed_dofs);
    
    % 3. Partition and Solve
    % U_free = K_ff \ (F_free - K_fc * U_fixed)
    
    U_full = zeros(nDofs, 1);
    U_full(fixed_dofs) = fixed_vals;
    
    F_effective = F(free_dofs) - Ke(free_dofs, fixed_dofs) * fixed_vals(:);
    
    U_calc = Ke(free_dofs, free_dofs) \ F_effective;
    
    U_full(free_dofs) = U_calc;    
    fprintf('[Solver] Static Solution Complete.\n');
end