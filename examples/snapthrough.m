% TEST_DispControl_SnapThrough.m
clear; clc; close all;

% 1. Create a Shallow Curved Panel (Arc)
% Material: Steel
E = 200e9; nu = 0.3; t = 0.05; 
Pre = FEM_Preprocessor_v2(E, nu, t);

% Define Profile: A shallow arc in X-Z plane
R = 6.0;       % Radius
Chord = 10.0;   % Width
H = sqrt(R^2 - (Chord/2)^2); % Rise
Angle = asin((Chord/2)/R);

% Profile Nodes (3 points for arc: Left, Mid-ish, Right)
% Actually, let's just use the 'arc' segment in extrusion
% Node 1: (-Chord/2, 0, 0)
% Node 2: (Chord/2, 0, 0)
% Center: (0, -sqrt(R^2 - (Chord/2)^2), 0)
n1 = [-Chord/2, 0, 0];
n2 = [ Chord/2, 0, 0];
n_center = [0, 0, -H];

% Extrude in Y direction
Length = 6; % Short strip

% We use the Preprocessor macros manually to set this up precisely
% Profile Nodes
nodes = [n1; n2; n_center]; 
% Segment: 1->2, type 'arc', 10 elems, center is node 3
segs = [1, 2, 3, 12]; 

% Extrude
direction = [0, 1, 0];
Pre.createExtrusion(nodes, segs, direction, Length, 9);

% 2. Boundary Conditions (Pin edges)
% Fix X, Y, Z at X = -0.5 and X = 0.5
% Select nodes
leftNodes = Pre.selectNodesByBox(-Chord/2-0.1, -Chord/2+0.1, -1, 1, -1, 1);
rightNodes = Pre.selectNodesByBox(Chord/2-0.1, Chord/2+0.1, -1, 1, -1, 1);

Pre.addBC([leftNodes; rightNodes], 1:3,0,'Support');

% 3. Control Node (Top Center)
% Find node with Max Z
% [~, centerNodeID] = max(Pre.Mesh.Nodes(:,3));
centerNodeID=Pre.selectNodesByBox(-0.1,0.1,2.9,3.1,R-H-0.1,R-H+0.1);
% centerNodeID = find(Pre.Mesh.Nodes(:,3)==max(Pre.Mesh.Nodes(:,3)));
% Z displacement control (pushing down)
target_disp = -2.80; % Push down past the snap point (H approx 0.06m)

% 4. Solve
Sol = FEM_Solver_NL(Pre);

% solveDisplacementControl(Node, DOF, Target, Steps, MaxIter, Tol)
% We push DOF 3 (Z)
Sol.solveDisplacementControl(centerNodeID, 3, target_disp, 20, 10, 1e-4);

%% 5. Post-Process
Post = FEM_Postprocessor(Pre, Sol);

opts.layer='Mid';
opts.scale=0.05;
opts.Nummode=2;
% A. Plot Reaction Curve
Post.plotReactionDispCurve(centerNodeID, 3);

% Expected Result: Force goes Negative (pushing), reaches a peak, 
% drops (softening), maybe snaps (goes back up) depending on depth.
Post.plotField('Displacement', opts);
title('Displacement Magnitude NL');
view(3);
% B. Animation
% Post.animateDisplacement(1.0, 0.1);
Post.animateScenario(centerNodeID, 3, 1, 0.5);