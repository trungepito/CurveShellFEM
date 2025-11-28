function solveBuckling(obj, numModes)
if isempty(obj.U)
    error('Must run solveStatic() before buckling!');
end

fprintf('[Solver] Assembling Geometric Stiffness (Kg)...\n');
obj.assembleKg();

% Partition matrices (remove fixed DOFs for eigensolver)
fixed_dofs = (obj.Model.BCs(:,1)-1)*5 + obj.Model.BCs(:,2);
free_dofs = 1:length(obj.GlobalF);
free_dofs(fixed_dofs) = [];

K_red = obj.GlobalK(free_dofs, free_dofs);
Kg_red = obj.GlobalKg(free_dofs, free_dofs);

fprintf('[Solver] Solving Eigenvalue Problem...\n');
opts.issym = 1;
% Solve K * phi = lambda * (-Kg) * phi
[~, D] = eigs(K_red, -Kg_red, numModes, 'sm', opts);
obj.BucklingFactors = diag(D);
end