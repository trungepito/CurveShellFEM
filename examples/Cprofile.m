% EXAMPLE_Extrusion_C_Section.m
clear; clc; close all

% 1. Init
Pre = FEM_Preprocessor_v2(2e5, 0.3, 20);

% 2. Define 2D Profile (C-Section in X-Y Plane)
% Dimensions
H =200; W = 200; R = 60;

% Key Coordinates (8 Points for the profile including arc centers)
% 1: Bot Flange Tip
% 2: Bot Flange Start
% 3: Web Start (Bot)
% 4: Web End (Top)
% 5: Top Flange Start
% 6: Top Flange Tip
% 7: Bot Arc Center
% 8: Top Arc Center

nodes = [
    W, 0, 0;         % 1
    R, 0, 0;
    0, R, 0;         % 2
    0,H-R,0;
    R, H, 0;         % 3
    W, H, 0;
    R, R, 0;
    R,H-R,0% 6
];

% Connectivity: {StartNode, EndNode, [CenterID], NumElems, }
% if [CenterID] is 0, it's straight/flat plate
segments = [
    1, 2, 0, 6;       % Bot Flange
    2, 3, 7, 4;    % Bot Corner (Center is Node 7)
    3, 4, 0, 6;      % Web
    4,5,8,4;
    5,6,0,6;
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
tipNodes = Pre.selectNodesOnPlane(3, specs(1));
% Pre.addNodalLoad(tipNodes, 3, -0.7*1000,'Load1'); % Distributed point load
Pre.addBC(Lend, 3,-10,'Support');
% 5. Solve & Plot
Sol = FEM_Solver(Pre);
% Sol.solveStatic();
Sol.solveStaticDisplacement();
Sol.solveBuckling(10);

% SolNLopt.numLoadSteps=20;
% SolNLopt.maxIter = 100; 
% SolNLopt.tol = 1e-6;
% SolNLopt.linesearch=0;
% Sol2=FEM_Solver_NL(Pre);
% Sol2.solveNonLinear(SolNLopt);
%%
Post = FEM_Postprocessor(Pre, Sol);
opts.layer='Top';
opts.scale=0.1;
opts.Nummode=1;
Post.plotField('Displacement', opts);
title('Extruded C-Section');
% 
for ii=1:10
opts.Nummode=ii;   
Post.plotField('Buckling', opts);
title('Buckling mode 1 (Bot)');
colormap jet;
view(3);
end
% % Plotting additional stress fields for analysis
% Post.plotField('SigmaX', opts);
% title('Sig X \sigma_y (Bottom)');
% 
% Post.plotField('SigmaZ', opts);
% title('Sig z \sigma_z (Through Thickness)');
% 
% Post.plotField('SigmaY', opts);
% title('SIgma y \sigma_x (Top)');
% % colormap jet;

% Post.plotField('VonMises', opts);
Post2 = FEM_Postprocessor(Pre, Sol2);
Post2.plotLoadDisplacement(tipNodes(1), 3); % Z-disp
% 
Post2.plotField('Displacement', opts);
title('Displacement Magnitude NL');
view(3);