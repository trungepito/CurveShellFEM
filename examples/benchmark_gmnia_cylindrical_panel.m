% benchmark_gmnia_cylindrical_panel.m
% Comprehensive GMNIA (Geometric & Material Nonlinear Analysis with Imperfections)
% Case: Cylindrical Panel under Central Point Load

clear; clc; close all;
fprintf('============================================================\n');
fprintf('  GMNIA BENCHMARK: Cylindrical Panel Stability\n');
fprintf('============================================================\n');

%% 1. Geometry and Material
E  = 3102.75; % Scordelis-Lo-like or similar test units
nu = 0.3;     
t  = 12.7;    
R  = 2540;    
L  = 508;
angle = 0.1;

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createCylinderPanel(R, L, -angle, angle);

% Material: Elastic (First stage for buckling)
nEl = 6;
Pre.meshAllPatches(nEl, nEl);
Pre.computeNormals();

%% 2. Boundary Conditions (Hinged Edges)
tol = 1.0;
nodes_bottom = Pre.selectNodesOnPlane(3, 0, 1000); % Z-plane near base? No, cylinder is curved.
% Better select by Z or X.
% Let's use hinged support on straight edges
nodes_long = [Pre.selectNodesOnPlane(2, -angle*R, tol); Pre.selectNodesOnPlane(2, angle*R, tol)];
Pre.addBC(nodes_long, 1, 0, 'Hinged_UX');
Pre.addBC(nodes_long, 2, 0, 'Hinged_UY');
Pre.addBC(nodes_long, 3, 0, 'Hinged_UZ');

% Central Load Node
nodeCoords = Pre.Mesh.Nodes;
d2center = sum((nodeCoords - [R, 0, L/2]).^2, 2);
[~, centerID] = min(d2center);
Pre.addNodalLoad(centerID, 3, -200000.0, 'Central_P');

%% 3. PRE-STAGE: Buckling for Imperfection
SolBuck = FEM_Solver(Pre);
SolBuck.solveStatic();
SolBuck.solveBuckling(1);
mode1 = SolBuck.ModeShapes(:, 1);

%% 4. STAGE 1: Imperfection Mapping
% Apply L/1000 imperfection based on 1st mode
Pre.applyImperfection(mode1, t/10); 

%% 5. STAGE 2: GMNIA (Nonlinear + Plasticity)
% Switch to Plastic Material
sigY = 50.0; % High enough for some elasticity
H_iso = 100.0;
Pre.setMaterialPlastic(sigY, H_iso);

opts = SolverOptions();
opts.Tolerance = 1e-3;
Sol = FEM_Solver_Adaptive(Pre, opts);
% Sol = FEM_Solver_ArcLength(Pre, opts);
% Stage Definition
S1 = LoadingStage(1.0); % Analysis up to P=500
S1.activateBC('Hinged_UX');
S1.activateBC('Hinged_UY');
S1.activateBC('Hinged_UZ');
S1.activateLoad('Central_P');
S1.ConstraintType = 'Riks';
S1.ArcLengthRadius = 0.010;

fprintf('[Solver] Running GMNIA Nonlinear...\n');
Sol.solve({S1});

%% 6. Post-Processing
Post = FEM_Postprocessor(Pre, Sol);
figure('Name','GMNIA Results','Color','w');
Post.plotField('Displacement', struct('scale', 1.0));
title('GMNIA: Final Deformed Shape');

figure('Name','Load-Displacement','Color','w');
Post.plotReactionDispCurve(centerID, 3);
title('GMNIA: Load-Displacement (Imperfection t/10)');
