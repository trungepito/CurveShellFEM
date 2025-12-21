% EXAMPLE_Complex_Beam.m
clear; clc; close all

% 1. Init
Pre = FEM_Preprocessor_v2(2e9, 0.3, 0.05);

% 2. Geometry: Generate Thin-Walled I-Beam
% Flange Width=0.2m, Height=0.3m, Length=2m
% The 'createIBeam' macro internally generates 3 patches
Pre.createIBeam(0.300, 0.200, 1,6,[6,20]);

% 3. Meshing
% Mesh all patches with 4 elements width, 20 elements length
% Pre.meshAllPatches(8, 20);

% 4. Selection & BCs
% Fix the Root (Z=0)
% Using 'plane' selector: Dim 3 (Z) is 0.0
web0=Pre.selectNodesByBox(-0.01,0.01,-0.01,0.01,-0.150,0.150);
cros0=Pre.selectNodesOnPlane(1,0,1e-5);
flange0=setdiff(cros0,web0);

webL=Pre.selectNodesByBox(6-0.01,6+0.01,-0.01,0.01,-0.150,0.150);
crosL=Pre.selectNodesOnPlane(1,6,1e-5);
flangeL=setdiff(crosL,webL);

% Select Top Flange Elements for Distributed Load
% Top Flange is at Y > 0.
% Box Selection: X(-0.2 to 0.2), Y(0.1 to 0.2), Z(0 to 2)
% topFlangeElems = Pre.selectNodesOnPlane(1,3*2000,1e-5);
webm=Pre.selectNodesByBox(3-0.01,3+0.01,-0.01,0.01,-0.150,0.150);
midspan = Pre.selectNodesOnPlane(1,3,1e-5);

%pinned at 0
Pre.addBC('nodeList',web0,2);
Pre.addBC('nodeList',flange0,3);
%pinned at L
Pre.addBC('nodeList',webL,2);
Pre.addBC('nodeList',flangeL,3);

Pre.addBC('nodeList',webm,1);

% Pre.addBC('plane', [1, 0.0], 1:6);
% Pre.addBC('plane', [1, 2000], 1:6);

% 5. Loads
% Select Top Flange Elements for Distributed Load
% Top Flange is at Y > 0.
% Box Selection: X(-0.2 to 0.2), Y(0.1 to 0.2), Z(0 to 2)

% Apply Pressure Perpendicular to Top Flange (Downwards/Normal)
% P = -1000 Pa (Inward/Down depending on normal orientation)
% Pre.addNodalLoad(cros0, 1,10000);
% Pre.addNodalLoad(crosL, 1,-10000);
% Pre.addNodalLoad(webm, 2,10);
% Loadnode=Pre.selectNodesOnPlane
%
target_disp=-20;
% 6. Solve
% Sol = FEM_Solver(Pre);
% Sol.solveStatic();
% 
% %%
% Sol.solveBuckling(10);
%%
% 6.2 Nonlinear GNI analysis
% SolNLopt.numLoadSteps=20;
% SolNLopt.maxIter = 100; 
% SolNLopt.tol = 1e-6;
% SolNLopt.linesearch=0;
% Sol2=FEM_Solver_NL(Pre);
% Sol2.solveNonLinear(SolNLopt)
Sol = FEM_Solver_NL(Pre);

% solveDisplacementControl(Node, DOF, Target, Steps, MaxIter, Tol)
% We push DOF 3 (Z)
Sol.solveDisplacementControl(crosL, 1, target_disp, 100, 30, 1e-4);
%%
% 7. Post
Post = FEM_Postprocessor(Pre, Sol);
opts.layer='Top';
opts.scale=50;
opts.Nummode=1;
Post.plotField('Displacement', opts);
title('I-Beam Bending under Pressure');

% for ii=1:10
%     opts.Nummode=ii;
% Post.plotField('Buckling', opts);
% title('Buckli0ng mode 1 (Bot)');
% colormap jet;
% end
colormap jet;
%% 
% 5. Post-Process
Post = FEM_Postprocessor(Pre, Sol2);

% A. Plot Curve
% Plot Displacement of a tip node (e.g., center of tip)
% midTip = tipNodes(round(end/2));
Post.plotLoadDisplacement(web0(1), 3); % Z-disp
opts.layer='Top';
opts.scale=10;
opts.Nummode=1;
Post2.plotField('Displacement', opts);
title('I-Beam Bending under Pressure');
% B. Animate
% Scale = 1.0 %(True scale to see real rotation)
Post.animateScenario(crosL(1), 1, 1, 0.5);