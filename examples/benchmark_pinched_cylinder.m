%% Pinched Cylinder Benchmark (Locking Test)
% R = 300, L = 600, t = 3, E = 3e6, nu = 0.3
% Theoretical Vertical Displacement at load point: 1.8248e-5 (for P=1)
% Note: Scordelis-Lo paper or similar shell test references.

clear; clc; addpath(genpath('.'));

% 1. Setup Preprocessor with Baseline Element
PreBase = FEM_Preprocessor_v2(3e6, 0.3, 3);
PreBase.createCylinderPanel(300, 600, 0, pi/2); % Quarter model
PreBase.meshAllPatches(10, 10);
PreBase.computeNormals();

% BCs: Diaphragm ends? No, simple pinched cylinder often uses free ends.
% For simplicity, we just constrain RBMs and apply point loads.
% Plane x=0 (Theta = pi/2): SymX (u_x=0, rot_y=0, rot_z=0)
symNodesX0 = PreBase.selectNodesOnPlane(1, 0, 1e-3);
PreBase.addBC(symNodesX0, [1, 5, 6], 0, 'SymX');

% Plane y=0 (Theta = 0): SymY (u_y=0, rot_x=0, rot_z=0)
symNodesY0 = PreBase.selectNodesOnPlane(2, 0, 1e-3);
PreBase.addBC(symNodesY0, [2, 4, 6], 0, 'SymY');

% Plane z=300 (Middle of Length L=600): SymZ (u_z=0, rot_x=0, rot_y=0)
symNodesZhalf = PreBase.selectNodesOnPlane(3, 300, 1e-3);
PreBase.addBC(symNodesZhalf, [3, 4, 5], 0, 'SymZ');

% 2. Rigid Diaphragm at End (z=0)
% u_x = 0, u_y = 0, (u_z is free)
endNodesZ0 = PreBase.selectNodesOnPlane(3, 0, 1e-3);
PreBase.addBC(endNodesZ0, [1, 2], 0, 'Diaphragm');

% Apply Pinched Load (at theta=0, z=300)
% For R=300, theta=0 is at (300, 0, z)
pID_Base = PreBase.selectNodesByBox(295, 305, -5, 5, 295, 305); 
PreBase.addNodalLoad(pID_Base(1), 1, -1.0, 'Pinch'); % Apply in X (Radial)

% solve Baseline
fprintf('\n--- Running Baseline (Curve8Element) ---\n');
SolBase = FEM_Solver(PreBase);
SolBase.solveStatic();
u_base = SolBase.U( (pID_Base(1)-1)*6 + 1);
fprintf('Baseline Displacement: %.4e\n', u_base);

% 2. Setup Preprocessor with ANS/EAS Element
PreANS = FEM_Preprocessor_v2(3e6, 0.3, 3);
PreANS.Material.ElementType = 'ANS_EAS'; % Enable Mitigation
PreANS.createCylinderPanel(300, 600, 0, pi/2);
PreANS.meshAllPatches(10, 10);
PreANS.computeNormals();
PreANS.addBC(symNodesX0, [1, 5, 6], 0, 'SymX');
PreANS.addBC(symNodesY0, [2, 4, 6], 0, 'SymY');
PreANS.addBC(symNodesZhalf, [3, 4, 5], 0, 'SymZ');
PreANS.addBC(endNodesZ0, [1, 2], 0, 'Diaphragm');
pID_ANS = PreANS.selectNodesByBox(295, 305, -5, 5, 295, 305);
PreANS.addNodalLoad(pID_ANS(1), 1, -1.0, 'Pinch');

% solve ANS/EAS
fprintf('\n--- Running Mitigation (Curve8Element_ANS_EAS) ---\n');
SolANS = FEM_Solver(PreANS);
SolANS.solveStatic();
u_ans = SolANS.U( (pID_ANS(1)-1)*6 + 1);
fprintf('ANS/EAS Displacement: %.4e\n', u_ans);

% Comparison
improvement = abs(u_ans / u_base);
fprintf('\nLocking Mitigation Factor: %.2f x\n', improvement);

% Comparison table
fprintf('\n====================================\n');
fprintf(' PINCHED CYLINDER BENCHMARK RESULTS\n');
fprintf('====================================\n');
fprintf(' Baseline (Curve8Element):     %.4e\n', u_base);
fprintf(' Mitigation (ANS/EAS):         %.4e\n', u_ans);
fprintf(' Ratio ANS_EAS / Baseline:     %.3f\n', abs(u_ans/u_base));
fprintf(' (>1 = less locking = more flexible = better)\n');
fprintf('====================================\n');
