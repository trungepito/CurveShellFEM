function solveBuckling(obj, numModes)
if isempty(obj.U)
    error('Must run solveStatic() before buckling!');
end

fprintf('[Solver] Assembling Geometric Stiffness (Kg)...\n');
obj.assembleKg();

% Partition matrices (remove fixed DOFs for eigensolver)
nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 6;
fixed_dofs = [];
if ~isempty(obj.Model.BCs)
    fixed_dofs = (obj.Model.BCs.Node-1)*6 + obj.Model.BCs.DOF;
    % rows = strcmp(obj.Model.BCs.Tag, tag) preserve for disp load!
end
free_dofs = setdiff(1:nDofs, fixed_dofs);

K_red = obj.GlobalK(free_dofs,free_dofs);
Kg_red = obj.GlobalKg(free_dofs,free_dofs);
K_red = 0.5*(K_red+K_red');
Kg_red =0.5* (Kg_red+Kg_red');
% K_red = obj.GlobalK;
% Kg_red = obj.GlobalKg;
fprintf('[Solver] Solving Eigenvalue Problem...\n');
% Solve K * phi = lambda * (-Kg) * phi
opts.disp=0;
[U, D] = eigs(-Kg_red,K_red, numModes, 'LR', opts);

% some special treatment maybe needed if Kg , Kred is not symmetric matrix
% tic
obj.ModeShapes = d_du_free_full(nDofs,numModes,U,free_dofs,fixed_dofs,obj.U(fixed_dofs));
% obj.ModeShapes=U;
obj.BucklingFactors = 1./diag(D);
% toc
end
% Store the mode shapes and buckling factors in the object

function v = d_du_free_full(n,nummodes, val, idx,fix_id,U_fix)
v = zeros(n,nummodes);
scale=max(abs(val),[],"all")/max(abs(U_fix));
if isinf(scale)
    scale=1;
end
v(idx,:) = val;
U_fix=U_fix*scale;
val_fix=repmat(U_fix,1,nummodes);
v(fix_id,:)=val_fix;
end