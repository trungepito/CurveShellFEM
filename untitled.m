% MAIN_RUN.m
clear; clc;

%% 1. PREPROCESSOR
% Initialize with material properties
Pre = FEM_Preprocessor(2e11, 0.3, 0.05); 

% Generate Mesh (Quarter Cylinder)
Pre.generateCylinderMesh(10, 50, 20, 20);

% Apply Boundary Conditions (Fix Bottom Edge)
% Assuming node mapping logic is internal or known...
% For demonstration, fix nodes with Z=0
nodes = Pre.Mesh.Nodes;
for i = 1:size(nodes,1)
    if abs(nodes(i,3)) < 1e-5 % Z approx 0
        Pre.addConstraint(i, 1); % Fix u
        Pre.addConstraint(i, 2); % Fix v
        Pre.addConstraint(i, 3); % Fix w
        % Pre.addConstraint(i, 4); % Fix alpha
        % Pre.addConstraint(i, 5); % Fix beta
    end
end

% Apply Load (Point load at top corner)
% [~, topNode] = max(nodes(:,3)); 
for i = 1:size(nodes,1)
    if abs(nodes(i,3)-max(nodes(:,3)))<=1e-5
        Pre.addLoad(i, 3, -100); % 1000N in X
    end
end

%% 2. SOLUTION
Sol = FEM_Solver(Pre);
% Static Solve
Sol.solveStatic();

% Buckling Solve (Optional)
% Sol.solveBuckling(3); 

%% 3. POSTPROCESSOR
Post = FEM_Postprocessor(Pre, Sol);

% Visualization
Post.plotField('Displacement', 'Top'); % Scale 100x
% Post.plotField('vonMises', 'Top'); % Scale 100x
% Post.plotPrincipalVectors()
% Post.plotVonMises();

% Text Output
% fprintf('First Buckling Load Multiplier: %.4f\n', Sol.BucklingFactors(1));