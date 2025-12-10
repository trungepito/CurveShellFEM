% EXAMPLE_Complex_Beam.m
clear; clc;

% 1. Init
Pre = FEM_Preprocessor_v2(200e9, 0.3, 20);

% 2. Geometry: Generate Thin-Walled I-Beam
% Flange Width=0.2m, Height=0.3m, Length=2m
% The 'createIBeam' macro internally generates 3 patches
Pre.createIBeam(300, 200, 2000,3,[4,20]);

% 3. Meshing
% Mesh all patches with 4 elements width, 20 elements length
% Pre.meshAllPatches(8, 20);

% 4. Selection & BCs
% Fix the Root (Z=0)
% Using 'plane' selector: Dim 3 (Z) is 0.0
Pre.addBC('plane', [1, 0.0], 1:6);
% Pre.addBC('plane', [1, 2000], 1:6);

% 5. Loads
% Select Top Flange Elements for Distributed Load
% Top Flange is at Y > 0.
% Box Selection: X(-0.2 to 0.2), Y(0.1 to 0.2), Z(0 to 2)
topFlangeElems = Pre.selectNodesOnPlane(1,3*2000,1e-5);

% Apply Pressure Perpendicular to Top Flange (Downwards/Normal)
% P = -1000 Pa (Inward/Down depending on normal orientation)
Pre.addNodalLoad(topFlangeElems, 1,-1000);
%
% 6. Solve
Sol = FEM_Solver(Pre);
Sol.solveStatic();

%%
Sol.solveBuckling(10);
%%6.2 Nonlinear GNI analysis
% numLoadSteps = 10; 
% maxIter = 200; 
% tol = 1e-6;
% Sol=FEM_Solver_NL(Pre);
% Sol.solveNonLinear( numLoadSteps, maxIter, tol)
%%
% 7. Post
Post = FEM_Postprocessor(Pre, Sol);
opts.layer='Top';
opts.scale=10000;
opts.Nummode=1;
% Post.plotField('Displacement', opts);
% title('I-Beam Bending under Pressure');
for ii=5:10
    opts.Nummode=ii;
Post.plotField('Buckling', opts);
title('Buckling mode 1 (Bot)');
end
colormap jet;
% 
% Post.plotField('SigmaY', opts);
% title('Bending Stress \sigma_x (Top)');
% % colormap jet;
% 
% Post.plotField('VonMises', opts);
% title('Bending Stress \sigma_x (Top)');
% colormap jet;
% the solution is weird, very weird!!, it's wrong, but i don't know how it
% is wrong 
% !!!! haha, i found the problem, how stupid i am haha