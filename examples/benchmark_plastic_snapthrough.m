% benchmark_plastic_snapthrough.m
% Interaction between Geometric and Material Nonlinearity.
clear; clc; close all;

% 1. Create a Shallow Curved Panel (Arc)
E = 200e9; nu = 0.3; t = 0.05; 
Pre = FEM_Preprocessor_v2(E, nu, t);

% Define Profile: A shallow arc
R = 10.0;       % Radius
Chord = 10.0;   % Width
H = R - sqrt(R^2 - (Chord/2)^2); % Rise (~1.34m)

n1 = [-Chord/2, 0, 0];
n2 = [ Chord/2, 0, 0];
n_center = [0, 0, - (R - H)]; % Standard definition: nodes at Z=0, center at Z=-(R-H)

% Profile Nodes for Preprocessor
profile_nodes = [n1; n2; 0, 0, -(R-H)]; 
% Segment: node 1 to node 2, type 'arc' (12), center node 3
segs = [1, 2, 3, 12]; 

% Extrude in Y direction
direction = [0, 1, 0];
Length = 5.0;
Pre.createExtrusion(profile_nodes, segs, direction, Length, 4); % Coarsened (was 8)

% 2. Material: J2 Plasticity
sigY = 180e6; % Yield Stress
H_mod = 2e9;  % Hardening
Pre.setMaterialPlastic(sigY, H_mod);

% 3. Boundary Conditions (Pinned edges at X = +/- 5)
leftNodes = Pre.selectNodesByBox(-Chord/2-0.1, -Chord/2+0.1, -1, 6, -1, 1);
rightNodes = Pre.selectNodesByBox(Chord/2-0.1, Chord/2+0.1, -1, 6, -1, 1);
Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Pinned');

% 4. Control Node (Peak Z)
maxZ = max(Pre.Mesh.Nodes(:,3));
centerNodeID = find(abs(Pre.Mesh.Nodes(:,3) - maxZ) < 1e-4 & abs(Pre.Mesh.Nodes(:,1)) < 0.1);
centerNodeID = centerNodeID(1); % Take first matching

target_disp = -2.5; % Push down from H=1.34 to Z=-1.16

% 5. Solve (Plastic)
SolPlast = FEM_Solver_NL(Pre);
fprintf('\n--- RUNNING PLASTIC ANALYSIS ---\n');
SolPlast.solveDisplacementControl(centerNodeID, 3, target_disp, 40, 15, 1e-3);

% 6. Solve (Elastic for Comparison)
PreElastic = FEM_Preprocessor_v2(E, nu, t);
PreElastic.createExtrusion(profile_nodes, segs, direction, Length, 8); 
PreElastic.addBC([leftNodes; rightNodes], 1:3, 0, 'Pinned');
SolElastic = FEM_Solver_NL(PreElastic);
fprintf('\n--- RUNNING ELASTIC ANALYSIS ---\n');
SolElastic.solveDisplacementControl(centerNodeID, 3, target_disp, 40, 15, 1e-3);

% 7. Solve (GNI for Comparison)
PreGNI = FEM_Preprocessor_v2(E, nu, t);
PreGNI.Material.Type = 'GeometricNL';  % Enable GNI
PreGNI.createExtrusion(profile_nodes, segs, direction, Length, 8);
PreGNI.addBC([leftNodes; rightNodes], 1:3, 0, 'Pinned');
SolGNI = FEM_Solver_NL(PreGNI);
fprintf('\n--- RUNNING GNI ANALYSIS ---\n');
SolGNI.solveDisplacementControl(centerNodeID, 3, target_disp, 40, 15, 1e-3);

% 8. Post-Process
figure('Name', 'Load-Displacement Comparison');
hold on; grid on;
% Extract histories
up = SolPlast.U_Hist;
if ~isempty(up)
    % Find the specific DOF entry (Z at centerNodeID)
    c_idx = (centerNodeID-1)*6 + 3;
    up_vals = up(c_idx, :); 
    rp_vals = SolPlast.ReactionHist;
    plot(up_vals, -rp_vals/1e3, 'r-', 'LineWidth', 2, 'DisplayName', 'Elastoplastic (J2)');
end

ue = SolElastic.U_Hist;
if ~isempty(ue)
    c_idx = (centerNodeID-1)*6 + 3;
    ue_vals = ue(c_idx, :);
    re_vals = SolElastic.ReactionHist;
    plot(ue_vals, -re_vals/1e3, 'k--', 'LineWidth', 2, 'DisplayName', 'Purely Elastic');
end

ug = SolGNI.U_Hist;
if ~isempty(ug)
    c_idx = (centerNodeID-1)*6 + 3;
    ug_vals = ug(c_idx, :);
    rg_vals = SolGNI.ReactionHist;
    plot(ug_vals, -rg_vals/1e3, 'b-', 'LineWidth', 2, 'DisplayName', 'GNI (Geometric NL)');
end

xlabel('Z-Displacement (m)'); ylabel('Reaction Force (kN)');
title('Plastic vs Elastic vs GNI Snap-Through');
legend show;

% 8. Visualize Plastic Front
PostP = FEM_Postprocessor(Pre, SolPlast);
PostP.plotField('PlasticFront');
title('Yield Penetration (%)');
view(3);
