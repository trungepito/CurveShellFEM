% benchmark_buckling_plate.m
% Verification of Linear Eigenvalue Buckling Solver
% Case: Simply Supported Square Plate under Uni-axial Compression (Nx)
% Theoretical Pcr = 4 * pi^2 * D / b^2 (for square plate)

clear; clc; close all;
fprintf('============================================================\n');
fprintf('  BUCKLING BENCHMARK: Simply Supported Square Plate\n');
fprintf('============================================================\n');

%% 1. Geometry and Material
E  = 200e9;   
nu = 0.3;     
t  = 0.01;    % 10 mm
b  = 1.0;     % Length/Width

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createPlate([0, 0, 0], b, b);

% Mesh: 10x10 elements
nEl = 10;
Pre.meshAllPatches(nEl, nEl);
Pre.computeNormals();

%% 2. Boundary Conditions & Loading
tol = 1e-4;
edgeX0 = Pre.selectNodesOnPlane(1, 0, tol);
edgeXb = Pre.selectNodesOnPlane(1, b, tol);
edgeY0 = Pre.selectNodesOnPlane(2, 0, tol);
edgeYb = Pre.selectNodesOnPlane(2, b, tol);
allEdges = unique([edgeX0; edgeXb; edgeY0; edgeYb]);

% Simply Supported (Uz=0)
Pre.addBC(allEdges, 3, 0, 'SS_Uz');
% In-plane Constraints: Fix Ux on entire X=0 edge to resist Nx
Pre.addBC(edgeX0, 1, 0, 'Fix_Ux_Line');
% Pin one node in Y to prevent RBM in Y
Pre.addBC(1, 2, 0, 'Fix_Uy');

% Loading: Uni-axial Compression Nx = 1.0 N/m
% Total Force F = Nx * b = 1.0 N.
% Distribute 1.0 N across edgeXb nodes (X-direction)
force_total = -1.0; 
nodes_load = edgeXb;
nL = length(nodes_load);
Pre.addNodalLoad(nodes_load, 1, force_total/nL, 'Comp_Nx');

%% 3. Solve Static (Prerequisite for Buckling)
Sol = FEM_Solver(Pre);
Sol.solveStatic();

%% 4. Solve Buckling
numModes = 3;
Sol.solveBuckling(numModes);

%% 5. Verification
D = (E * t^3) / (12 * (1 - nu^2));
Pcr_theory = (4 * pi^2 * D) / (b^2); % [N/m]
Pcr_sim = Sol.BucklingFactors(1);

fprintf('\n--- Buckling Results ---\n');
fprintf('Theoretical Pcr: %.4e N/m\n', Pcr_theory);
fprintf('Simulated Pcr:   %.4e N/m\n', Pcr_sim);
fprintf('Error:           %.2f%%\n', 100*(Pcr_sim - Pcr_theory)/Pcr_theory);

if abs(100*(Pcr_sim - Pcr_theory)/Pcr_theory) < 5.0
    fprintf('[PASS] Buckling factor within 5%% tolerance.\n');
else
    fprintf('[FAIL] Buckling factor outside tolerance.\n');
end

%% 6. Visualization
Post = FEM_Postprocessor(Pre, Sol);
figure('Name','1st Buckling Mode','Color','w');
opts_plot.scale = 0.2; 
opts_plot.Nummode = 1;
Post.plotField('Buckling', opts_plot);
title(sprintf('1st Buckling Mode (Pcr = %.2e)', Pcr_sim));
