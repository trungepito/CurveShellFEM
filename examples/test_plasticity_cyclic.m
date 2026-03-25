% test_plasticity_cyclic.m
% Verification of Bauschinger Effect using Cyclic Loading.
clear; clc; close all;

% 1. Create a Single Element Strip
E = 200e9; nu = 0.3; t = 0.01; 
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.addKeypoint(0,0,0); Pre.addKeypoint(0.1,0,0);
Pre.addKeypoint(0.1,0.02,0); Pre.addKeypoint(0,0.02,0);
l1 = Pre.addLine(1,2,'straight'); l2 = Pre.addLine(2,3,'straight');
l3 = Pre.addLine(3,4,'straight'); l4 = Pre.addLine(4,1,'straight');
Pre.addPatch(l1,l2,l3,l4);
Pre.meshAllPatches(1, 1);
Pre.computeNormals();

% 2. Material: J2 with combined hardening
sigY = 250e6; 
H_iso = 0;      % Pure Kinematic for clear Bauschinger view
H_kin = 20e9;   % Significant kinematic hardening
Pre.setMaterialPlastic(sigY, H_iso, H_kin); 

% 3. BCs: Fixed left, Axial displacement right
leftNodes = Pre.selectNodesByBox(-0.001, 0.001, -1, 1, -1, 1);
Pre.addBC(leftNodes, 1:6, 0, 'Fixed');
rightNodes = Pre.selectNodesByBox(0.099, 0.101, -1, 1, -1, 1);
controlNode = rightNodes(1);

% 4. Solver
Sol = FEM_Solver_NL(Pre);

% --- CYCLE 1: Tension ---
fprintf('\n--- CYCLE 1: TENSION ---\n');
Sol.solveDisplacementControl(controlNode, 1, 0.002, 10, 5, 1e-4);

% --- CYCLE 2: Compression ---
fprintf('\n--- CYCLE 2: COMPRESSION ---\n');
Sol.solveDisplacementControl(controlNode, 1, -0.002, 20, 5, 1e-4);

% --- CYCLE 3: Re-Tension ---
fprintf('\n--- CYCLE 3: RE-TENSION ---\n');
Sol.solveDisplacementControl(controlNode, 1, 0.002, 20, 5, 1e-4);

% 5. Plot Results
figure('Name', 'Cyclic Loading: Bauschinger Effect');
U_tip = Sol.U_Hist((controlNode-1)*6 + 1, :);
Force = Sol.ReactionHist;
plot(U_tip * 1000, Force/1e3, 'b-o', 'LineWidth', 2);
grid on;
xlabel('Axial Displacement (mm)'); ylabel('Axial Force (kN)');
title('Cyclic Response highlighting Bauschinger Effect');

% Annotate initial yield
hold on;
plot(0.125, sigY*0.01*0.02/1e3, 'rx', 'MarkerSize', 10);
text(0.15, sigY*0.01*0.02/1e3, ' First Yield');
