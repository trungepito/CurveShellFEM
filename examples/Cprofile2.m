% EXAMPLE_Extrusion_C_Section.m
clear; clc; close all

% 1. Init
Pre = FEM_Preprocessor_v2(2.1e5, 0.3, 4);

% 2. Define 2D Profile (C-Section in X-Y Plane)
% Dimensions
H =300; W = 150; R = 20;Lip=50;

% Key Coordinates (8 Points for the profile including arc centers)
% 1: Bot Flange Tip
% 2: Bot Flange Start
% 3: Web Start (Bot)
% 4: Web End (Top)
% 5: Top Flange Start
% 6: Top Flange Tip
% 7: Bot Arc Center
% 8: Top Arc Center

nodes = [W+R,R+Lip,0;
    W+R,R,0;
    W, 0, 0;         % 1
    R, 0, 0;
    0, R, 0;         % 2
    0,H-R,0;
    R, H, 0;         % 3
    W, H, 0;
    W+R,H-R,0;
    W+R,H-R-Lip,0;
    W,R,0;
    R, R, 0;
    R,H-R,0;
    W,H-R,0;% 6
];

% Connectivity: {StartNode, EndNode, [CenterID], NumElems, }
% if [CenterID] is 0, it's straight/flat plate
segments = [
    1, 2, 0, 3;
    2,3,11,2;% Bot Flange
    3, 4, 0, 6;    % Bot Corner (Center is Node 7)
    4, 5, 12, 2;
    5,6,0,8;
    6,7,13,2;
    7,8,0,6;
    8,9,14,2;
    9,10,0,3          % Web
    ];

% 3. Extrusion Options
% Direction Z
direction = [0, 0, 1];

% OPTION A: Uniform Extrusion (Total Length 1.0m, 20 Elements total)
% specs = 1.0; 
% meshZ = 20;

% OPTION B: Variable Extrusion (Stiffeners Logic)
% Let's create a beam with different mesh densities or lengths
% Segments: 0.1m, 0.8m, 0.1m (Modeling end effects)
specs = [2000]; 
% Mesh Density per segment: 5 elems, 20 elems, 5 elems
meshZ = [30];

fprintf('Extruding Profile...\n');
Pre.createExtrusion(nodes, segments, direction, specs, meshZ);

% 4. BCs and Loads
% Fix Root (Z=0)
Rend=Pre.selectNodesOnPlane(3,0,1e-4);
Lend=Pre.selectNodesOnPlane(3,sum(specs),1e-4);
Pre.addBC(Rend, 1:6,0,'Support');
Pre.addBC(Lend, 1:2,0,'Support');

% Load at Tip (Z=3)
% Select nodes via plane selector
% tipNodes = Pre.selectNodesOnPlane(3, specs(1));
Pre.addNodalLoad(Lend, 3, -10*1000,'Load1'); % Distributed point load
Pre.addBC(Lend, 3,-15,'Disp');
Pre.addBC(Lend, 3,0,'Undisp');
% 5. Solve & Plot
Sol = FEM_Solver(Pre);
% Sol.solveStatic();
Sol.solveStaticDisplacement();
% Sol.solveBuckling(10);
S1 = LoadingStage(1.0);
S1.activateBC('Support');
S1.activateBC('Disp');
% S1.activateLoad('Load1');
S2=LoadingStage(1.0);
S2.activateBC('Support');
S2.activateBC('Undisp')

S3=LoadingStage(1.0);
S3.activateBC('Support');
S3.activateLoad('Load1');

solOpt=SolverOptions;
Sol2=FEM_Solver_Adaptive(Pre,solOpt);
Sol2.solve({S1});
%%
Post = FEM_Postprocessor(Pre, Sol2);
opts.layer='Mid';
opts.scale=10;
opts.Nummode=2;
Post.plotField('Displacement', opts);
title('Displacement Magnitude');
view(3)
% %%
% % Post.plotField('VonMises', opts);
% Post2 = FEM_Postprocessor(Pre, Sol2);
% 
% % Post2.animateDisplacement(10,2,1);
% for i=1:size(Sol2.U_Hist,2)
%     Sol2.U=Sol2.U_Hist(:,i);
% Post2.plotField('Displacement', opts);
% title('Displacement Magnitude NL');
% end
% view(3);