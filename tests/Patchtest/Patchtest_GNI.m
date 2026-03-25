% Patchtest_GNI.m - Patch test for Curve8Element_GNI
clear; clc;

fprintf('================================================\n');
fprintf('      GNI ELEMENT PATCH TEST                    \n');
fprintf('================================================\n');

% Simple 1-element test for GNI convergence
nDiv = 1;
[nodes, elements, ~, ~] = getPatchMesh(nDiv);

% Setup model with GeometricNL type
E = 200e9; nu = 0.3; t = 0.01;
Model = FEM_Preprocessor_v2(E, nu, t);
Model.Mesh.Nodes = nodes;
Model.Mesh.Elements = elements;
Model.Mesh.Normals = repmat([0 0 1], size(nodes,1), 1);
Model.Material.Type = 'GeometricNL';  % Set type for GNI

% Boundary conditions: fix boundaries, apply load
bnd_nodes = [1, 2, 3, 4];  % Corner nodes
for i = bnd_nodes
    Model.addBC(i, 1:6, 0, 'Support');  % Fix all DOF
end

% Apply small load at center node (node 5)
Model.Loads = [Model.Loads; {5, 3, 1000, 'Load'}];

% Solve nonlinear
SolNLopt.numLoadSteps = 10;
SolNLopt.maxIter = 20;
SolNLopt.tol = 1e-6;

try
    Solver.solveNonLinear(SolNLopt);
    U = Solver.U;
    fprintf('GNI Patch Test: Converged successfully\n');
    fprintf('Max displacement: %.6f\n', max(abs(U)));
catch ME
    fprintf('GNI Patch Test: Failed to converge\n');
    fprintf('Error: %s\n', ME.message);
end