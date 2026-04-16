function solveBuckling(obj, numModes)
% SOLVEBUCKLING  Linear Eigenvalue Buckling Analysis.
%
% Prerequisite: solveStatic() must be run first to establish stress state.
%
% Solves: K * phi = lambda * (-Kg) * phi
% where lambda = critical load factor (Pcr / P_ref).
%
% v3.0 Fix: Changed from eigs(...,'LR') to eigs(K, -Kg, n, 'SM').
% 'LR' returned the largest eigenvalues of (-Kg\K), which are the
% LEAST critical modes.  The physical smallest positive lambda (lowest
% critical load) is found by 'SM' on the correctly stated A*x = lambda*B*x.

if isempty(obj.U)
    error('FEM_Solver:solveBuckling', ...
        'Must run solveStatic() before solveBuckling() to establish stress state.');
end

fprintf('[Solver] Assembling Geometric Stiffness (Kg)...\n');
obj.assembleKg();

% Reuse FreeDofs from solveStatic if available to ensure dimension consistency
nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
if isprop(obj, 'FreeDofs') && ~isempty(obj.FreeDofs)
    free_dofs = obj.FreeDofs;
    fixed_dofs = setdiff(1:nDofs, free_dofs)';
else
    fixed_dofs = [];
    if ~isempty(obj.Model.BCs)
        if istable(obj.Model.BCs)
            fixed_dofs = unique((obj.Model.BCs.Node - 1) * 6 + obj.Model.BCs.DOF);
        else
            fixed_dofs = unique(([obj.Model.BCs.Node] - 1) * 6 + [obj.Model.BCs.DOF]);
        end
    end
    free_dofs = setdiff(1:nDofs, fixed_dofs)';
end

K_red  = obj.GlobalK(free_dofs,  free_dofs);
Kg_red = obj.GlobalKg(free_dofs, free_dofs);

% Dimension Safety Check (A5 Unified Architecture)
if size(K_red,1) ~= size(Kg_red,1)
    error('FEM_Solver:sizeMismatch', ...
        'Dimension mismatch in Buckling: K_red(%dx%d) vs Kg_red(%dx%d). FreeDOFs: %d', ...
        size(K_red,1), size(K_red,2), size(Kg_red,1), size(Kg_red,2), length(free_dofs));
end

% Enforce symmetry (eliminate numerical asymmetry from assembly)
K_red  = 0.5 * (K_red  + K_red');
Kg_red = 0.5 * (Kg_red + Kg_red');

fprintf('[Solver] Solving Eigenvalue Problem (K*phi = lambda*(-Kg)*phi)...\n');
opts_eigs.disp = 0;
opts_eigs.tol  = 1e-10;

% Use 'SM' to find smallest-magnitude eigenvalues = lowest critical loads.
[V, D] = eigs(K_red, -Kg_red, numModes, 'SM', opts_eigs);

lambda_all = diag(D);

% Keep only real, positive factors (negative = already buckled / snap-back)
valid = real(lambda_all) > 0 & abs(imag(lambda_all)) < 1e-6 * abs(real(lambda_all)) + eps;
lambda_phys = sort(real(lambda_all(valid)));

obj.BucklingFactors = lambda_phys;
obj.ModeShapes      = d_du_free_full(nDofs, numModes, real(V), free_dofs, fixed_dofs, obj.U(fixed_dofs));

% Shout out!!!
evtData=SolverLinearEventData(obj.ModeShapes,lambda_phys);
notify(obj, 'Lin_sol', evtData);

fprintf('[Solver] Critical Load Factors: ');
fprintf('%.4e  ', obj.BucklingFactors(1:min(3, end)));
fprintf('\n');
end

% -----------------------------------------------------------------------
function v = d_du_free_full(n, nummodes, val, idx, fix_id, U_fix)
% Expand free-DOF eigenvectors back to full n-DOF space.
v = zeros(n, nummodes);
v(idx, :) = val;
if ~isempty(U_fix) && max(abs(U_fix)) > 0
    scale = max(abs(val), [], 'all') / max(abs(U_fix));
    if ~isinf(scale) && ~isnan(scale)
        v(fix_id, :) = repmat(U_fix * scale, 1, nummodes);
    end
end
end