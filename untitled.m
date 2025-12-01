% MAIN_RUN.m
clear; clc; close all
tol=1e-5;
L=20;
%% 1. PREPROCESSOR
% Initialize with material properties
% tic
Pre = FEM_Preprocessor(2e11, 0.3, 0.5); 

% Generate Mesh (Quarter Cylinder)
Pre.generateCylinderMesh(20, L, 10, 10);

% Apply Boundary Conditions (Fix Bottom Edge)
% Assuming node mapping logic is internal or known...
% For demonstration, fix nodes with Z=0
nodes = Pre.Mesh.Nodes;
for i = 1:size(nodes,1)

    x = nodes(i,1);
    y = nodes(i,2);
    z = nodes(i,3);

    is_boundary = abs(z) < tol || abs(z-L) < tol;
    if is_boundary % Z approx 0
        % Pre.addConstraint(i, 1); % Fix u
        Pre.addConstraint(i, 2); % Fix v
        Pre.addConstraint(i, 3); % Fix w
        % Pre.addConstraint(i, 4); % Fix rot1
        % Pre.addConstraint(i, 5); % Fix rot2
    end
end

% Apply Load (Point load at top corner)
% [~, topNode] = max(nodes(:,3)); 
for i = 1:size(nodes,1)
    if abs(nodes(i,3)-L)<=1e-5
        Pre.addLoad(i, 1, -1000); % 1000N in X
    end
    if abs(nodes(i,3))<=1e-5
        Pre.addLoad(i, 1, 1000); % 1000N in X
    end
end
% toc
%% 2. SOLUTION
% tic
Sol = FEM_Solver(Pre);
% Static Solve
Sol.solveStatic();

% Buckling Solve (Optional)
Sol.solveBuckling(3); 
% toc
%% 3. POSTPROCESSOR
tic
Post = FEM_Postprocessor(Pre, Sol);
opts.layer='Top';
opts.scale=1.5;
opts.Nummode=1;
% Visualization
Post.plotField('Displacement', opts); % Scale 100x
Post.plotField('vonMises', opts); % Scale 100x
Post.plotField('Buckling', opts);
toc
% Post.plotPrincipalVectors()
% Post.plotVonMises();

% Text Output
% fprintf('First Buckling Load Multiplier: %.4f\n', Sol.BucklingFactors(1));