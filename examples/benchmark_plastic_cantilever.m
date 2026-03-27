% benchmark_plastic_cantilever.m
% Formation of a Plastic Hinge in a Cantilever Plate.
clear; clc; close all;

% 1. Create a Narrow Strip (to act like a beam)
E = 200e9; nu = 0.3; t = 0.02; 
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createPlate([0,0,0], 1.0, 0.05); % Narrower

% Mesh: 10 elements long, 1 wide
Pre.meshAllPatches(10, 1);
Pre.computeNormals();

% 2. Material: J2 Plasticity
% Higher hardening for better stability
Pre.setMaterialPlastic(250e6, 10e9); 

% 3. BCs: Fixed at X=0 (Full edge)
leftNodes = Pre.selectNodesByBox(-0.01, 0.01, -1, 1, -1, 1);
Pre.addBC(leftNodes, 1:6, 0, 'Fixed');

% 4. Tip Load Node (X=1.0, Center)
rightNodes = Pre.selectNodesByBox(0.99, 1.01, -1, 1, -1, 1);
% Pick the node closest to Y=0.025 (center)
[~, idx] = min(abs(Pre.Mesh.Nodes(rightNodes, 2) - 0.025));
tipNodeID = rightNodes(idx);

% 5. Solve using Displacement Control (Push Down)
target_disp = -0.15;
% Convert to new Stage-based solver architecture
Pre.addBC(tipNodeID, 3, target_disp, 'Tip_Disp');

opts = SolverOptions();
opts.Tolerance = 1e-3;
opts.MaxIterations = 15;
opts.InitialDt = 1/20; % equivalent to 20 steps in old `solveDisplacementControl`

Sol = FEM_Solver_Adaptive(Pre, opts);
S1 = LoadingStage(1.0);
S1.activateBC('Fixed');
S1.activateBC('Tip_Disp');

fprintf('\n--- RUNNING PLASTIC CANTILEVER ANALYSIS ---\n');
Sol.solve({S1});

% 6. Post-Process
Post = FEM_Postprocessor(Pre, Sol);

% Plot Yield Penetration
Post.plotField('PlasticFront');
title('Plastic Hinge Formation (Yield Penetration %)');
view(3);

% Plot Load-Disp
figure('Name', 'Cantilever Response');
plot(Sol.U_Hist((tipNodeID-1)*6+3, :), -Sol.ReactionHist/1e3, 'r-o', 'LineWidth', 2);
xlabel('Tip Displacement (m)'); ylabel('Reaction Force (kN)');
title('Load-Displacement Curve (Material Softening)');
grid on;
