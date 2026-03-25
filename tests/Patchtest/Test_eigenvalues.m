% Test_Eigenvalues.m
% Create 1 single rectangular element
Pre = FEM_Preprocessor_v2(200e9, 0.3, 0.01);
nodes = [0 0 0; 1 0 0; 1 1 0; 0 1 0;0.5 0 0;1 0.5 0;0.5 1 0;0 0.5 0];
% Pre.createExtrusion(nodes, [1,2,0,1], [0 0 1], 0, 1); % Dummy just to get element
Pre.Mesh.Nodes = nodes;
Pre.Mesh.Elements = [1 2 3 4 5 6 7 8];
Pre.Mesh.Normals = [zeros(8,2),ones(8,1)];

Sol = FEM_Solver(Pre);
Sol.solveStatic(); % Get global K

% Compute Eigenvalues
evals = eig(full(Sol.GlobalK));
evals = sort(abs(evals));

% Count Zeros (Using a small tolerance like 1e-5)
nZeros = sum(evals < 1e-5);

fprintf('Number of Zero Energy Modes: %d\n', nZeros);
if nZeros == 6
    disp('    [PASS] Correct Rank (6 Rigid Body Modes).');
elseif nZeros > 6
    disp('    [FAIL] Spurious Mechanisms Detected (Hourglassing).');
else
    disp('    [FAIL] Element is Locking (Too Stiff).');
end