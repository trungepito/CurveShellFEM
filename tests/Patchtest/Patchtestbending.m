% Test_Patch_Bending.m
clear; clc;

fprintf('================================================\n');
fprintf('      PLATE BENDING PATCH TEST (Constant Curvature)\n');
fprintf('================================================\n');

% 1. Setup Same Mesh (Case 2: 2x2 is usually sufficient)
nDiv = 2;
[nodes, elements, bnd_nodes, int_nodes] = getPatchMesh(nDiv);

% 2. Model Setup
E = 200e9; nu = 0.3; t = 0.01;
Model = FEM_Preprocessor_v2(E, nu, t);
Model.Mesh.Nodes = nodes;
Model.Mesh.Elements = elements;
% Normals point in Z
Model.Mesh.Normals = repmat([0 0 1], size(nodes,1), 1);

% 3. Apply Boundary Conditions
% Field: w = 1e-3 * (x^2 + xy + y^2)
% We enforce w, theta_x, theta_y on the BOUNDARIES.
% We check if the INTERNAL nodes match this surface.

for i = 1:length(bnd_nodes)
    nid = bnd_nodes(i);
    x = nodes(nid, 1);
    y = nodes(nid, 2);

    [w, tx, ty] = getBendingExact(x, y);

    % Constrain w (DOF 3), theta_x (DOF 4), theta_y (DOF 5)
    Model.addBC('node', nid, 3, w);
    Model.addBC('node', nid, 4, tx);
    Model.addBC('node', nid, 5, ty);

    % Constrain in-plane (u,v, theta_z) to 0 to isolate bending
    Model.addBC('node', nid, [1 2 6], 0);
end

% Also fix in-plane DOFs for internal nodes (pure bending test)
if ~isempty(int_nodes)
    Model.addBC('nodeList', int_nodes, [1 2 6], 0);
end

% 4. Solve
Solver = FEM_Solver(Model);
Solver.solveStatic();

% 5. Verification
fprintf('    Node |      X         Y      |    w_fem      w_exact   |   tx_fem     tx_exact   |   ty_fem     ty_exact   |   Error\n');
fprintf('    ----------------------------------------------------------------------------------------------------------------------\n');

U = Solver.U;
max_err = 0;

check_nodes = 1:size(nodes,1);
for i = 1:length(check_nodes)
    nid = check_nodes(i);
    x = nodes(nid, 1);
    y = nodes(nid, 2);

    [w_ex, tx_ex, ty_ex] = getBendingExact(x, y);

    % Extract FEM results
    % DOF 3=w, 4=tx, 5=ty
    w_fem  = U( (nid-1)*6 + 3 );
    tx_fem = U( (nid-1)*6 + 4 );
    ty_fem = U( (nid-1)*6 + 5 );

    % Error metric (norm of displacement + rotations scaled slightly)
    err = sqrt( (w_fem - w_ex)^2 + (tx_fem - tx_ex)^2 + (ty_fem - ty_ex)^2 );
    max_err = max(max_err, err);

    % Print internal nodes primarily
    if ismember(nid, int_nodes)
        type = 'INT';
    else
        type = 'BND';
    end

    if ismember(nid, int_nodes)
        fprintf('    %3d  | %8.2f %8.2f | %10.5e %10.5e | %10.5e %10.5e | %10.5e %10.5e | %8.2e (%s)\n', ...
            nid, x, y, w_fem, w_ex, tx_fem, tx_ex, ty_fem, ty_ex, err, type);
    end
end

if max_err < 1e-8
    fprintf('\n    [PASS] Bending Patch Test Passed! Error: %e\n', max_err);
else
    fprintf('\n    [FAIL] Bending Patch Test Failed. Error: %e\n', max_err);
end

% --- Helper Function ---
function [w, tx, ty] = getBendingExact(x, y)
% Quadratic Surface (Constant Curvature)
c = 1e-3;
w  = c * 0.5 * (x^2 + x*y + y^2);

% Small angle approximation derivatives
dw_dy = c * 0.5 * (x + 2*y);
dw_dx = c * 0.5 * (2*x + y);

% Rotations
tx =  dw_dy;  % Rotation about X axis
ty = -dw_dx;  % Rotation about Y axis (note the sign!)
end