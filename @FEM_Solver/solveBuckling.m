function solveBuckling(obj, numModes)
if isempty(obj.U)
    error('Must run solveStatic() before buckling!');
end

fprintf('[Solver] Assembling Geometric Stiffness (Kg)...\n');
obj.assembleKg();

% Partition matrices (remove fixed DOFs for eigensolver)
% fixed_dofs = (obj.Model.BCs(:,1)-1)*6 + obj.Model.BCs(:,2);
% free_dofs = 1:length(obj.GlobalF);
% free_dofs(fixed_dofs) = [];

K_red = obj.GlobalK;
Kg_red = obj.GlobalKg;

fprintf('[Solver] Solving Eigenvalue Problem...\n');
% Solve K * phi = lambda * (-Kg) * phi
opts.disp=0;
[U, D] = eigs(-Kg_red,K_red, numModes, 'LR', opts);

% some special treatment maybe needed if Kg , Kred is not symmetric matrix
obj.ModeShapes = U;
obj.BucklingFactors = 1./diag(D);
end
% Store the mode shapes and buckling factors in the object

% function v = d_du_free_full(n, val, idx)
%     v = zeros(n,1);
%     v(idx) = val;
% end