% MAIN_RUN_Updated.m
clear; clc; close all;

%% 0. CONFIGURATION
% Select your test scenario here:

% BC_CASE:
% 1 = Cantilever (Fixed Bottom)
% 2 = Simply Supported (Pinned Bottom & Top, free rotation)
% 3 = Clamped-Clamped (Fixed Bottom & Top)
BC_CASE = 1;

% LOAD_CASE:
% 1 = Tip Point Load (Concentrated Force at Top Edge Node)
% 2 = Internal Pressure (Uniform Radial Distributed Load)
% 3 = Wind Load (Distributed Pressure varying with Angle)
% 4 = Axial Compression (Ring Load on Top Edge)
LOAD_CASE = 3;

% Mesh Density
Nu = 20; % Circumferential elements
Nv = 10; % Axial elements

%% 1. PREPROCESSOR
fprintf('--- INITIALIZING MODEL ---\n');
% Steel: E=2e11, nu=0.3, t=0.5
Pre = FEM_Preprocessor_CAD(2e11, 0.3, 0.5);

% Dimensions
R = 20.0;
L = 50.0;

% Generate Mesh (Full 360 Cylinder)
% Using the Optimized Patch Generator
% Params: (R, L, Nu, Nv, StartAngle, EndAngle)
Pre.generateCylinderPatch(R, L, Nu, Nv, 0, 2*pi);

fprintf('Mesh: %d Nodes, %d Elements.\n', size(Pre.Mesh.Nodes,1), size(Pre.Mesh.Elements,1));

%% 2. BOUNDARY CONDITIONS
fprintf('--- APPLYING BCs (Case %d) ---\n', BC_CASE);

% Helper: Dimensions index (1=X, 2=Y, 3=Z)
dim_Z = 3;

switch BC_CASE
    case 1 % Cantilever (Fixed Bottom)
        % Fix All 6 DOFs at Z=0
        Pre.applyBC_Coordinate(dim_Z, 0.0, 1:6);

    case 2 % Simply Supported (Pinned Ends)
        % Bottom (Z=0): Fix Translations (1,2,3)
        Pre.applyBC_Coordinate(dim_Z, 0.0, 1:3);

        % Top (Z=L): Fix Translation X,Y (1,2) but allow Z movement?
        % Usually SS implies fixed translation. Let's fix 1,2.
        Pre.applyBC_Coordinate(dim_Z, L, 1:2);

    case 3 % Clamped-Clamped
        % Fix All 6 DOFs at Z=0 and Z=L
        Pre.applyBC_Coordinate(dim_Z, 0.0, 1:6);
        Pre.applyBC_Coordinate(dim_Z, L,   1:6);
end

%% 3. LOADS
fprintf('--- APPLYING LOADS (Case %d) ---\n', LOAD_CASE);

allElems = 1:size(Pre.Mesh.Elements, 1);

switch LOAD_CASE
    case 1 % Concentrated Tip Load
        % Find a node at Top Edge (Z=L) with max X
        nodes = Pre.Mesh.Nodes;
        % Find nodes at Z=L
        top_indices = find(abs(nodes(:,3) - L) < 1e-4);
        % Among top nodes, find the one with max X (Angle = 0)
        [~, max_x_idx] = max(nodes(top_indices, 1));
        targetNode = top_indices(max_x_idx);

        % Apply 10,000 N in -X direction
        Pre.Loads = [Pre.Loads; targetNode, 1, -10000];
        fprintf('Applied Point Load at Node %d\n', targetNode);

    case 2 % Uniform Internal Pressure
        % Function: @(r,theta,z) [Fr; Fth; Fz]
        % 1000 Pa Outward
        loadFunc = @(r, th, z) [1000; 0; 0];
        Pre.applyCylindricalLoad(allElems, loadFunc);
        fprintf('Applied Uniform Internal Pressure.\n');

    case 3 % Wind Load (Varying with Theta)
        % Pressure = P_max * cos(theta)
        % Pushes in on windward, pulls out on leeward
        P_max = 500;
        loadFunc = @(r, th, z) [-P_max * cos(th); 0; 0]; % Negative = Inward at th=0
        Pre.applyCylindricalLoad(allElems, loadFunc);
        fprintf('Applied Directional Wind Load.\n');

    case 4 % Axial Compression (Ring Load)
        % Apply Downward Force on all Top Edge Nodes
        % Find Top Nodes
        nodes = Pre.Mesh.Nodes;
        top_indices = find(abs(nodes(:,3) - L) < 1e-4);

        TotalForce = -1e6; % 1 MN Down
        ForcePerNode = TotalForce / length(top_indices);

        for k = 1:length(top_indices)
            Pre.Loads = [Pre.Loads; top_indices(k), 3, ForcePerNode];
        end
        fprintf('Applied Axial Ring Load.\n');
end

%% 4. SOLUTION
fprintf('--- SOLVING ---\n');
tic;
Sol = FEM_Solver(Pre);
Sol.solveStatic();
solveTime = toc;
fprintf('Solved in %.4f seconds.\n', solveTime);

% Check for NaN or Inf (Singularity Check)
if any(isnan(Sol.U)) || any(isinf(Sol.U))
    error('Solution diverged! Matrix likely singular. Check BCs or Drilling Stiffness.');
end

%% 5. POST-PROCESSOR
fprintf('--- VISUALIZATION ---\n');
Post = FEM_Postprocessor(Pre, Sol);

% A. Deformation Plot
figure('Name', 'Deformation', 'Color', 'w');
Post.plotField('Displacement', 'Top');
title(sprintf('Displacement (BC: %d, Load: %d)', BC_CASE, LOAD_CASE));

% B. Stress Plot
figure('Name', 'Von Mises Stress', 'Color', 'w');
Post.plotField('VonMises', 'Top');
title('Von Mises Stress (Top Surface)');

% C. Load Vector Check (Visual Verification)
figure('Name', 'Load Verification', 'Color', 'w');
hold on; axis equal; grid on; view(3);
% Plot Mesh Wireframe
patch('Vertices', Pre.Mesh.Nodes, 'Faces', Pre.Mesh.Elements(:,[1,2,3,4]), ...
    'FaceColor', 'none', 'EdgeColor', [0.8 0.8 0.8]);

% Extract Force Vectors
Lds = Pre.Loads;
if ~isempty(Lds)
    % Scale arrows based on model size
    arrowScale = L / 10 / max(abs(Lds(:,3)));
    if arrowScale == 0 || isinf(arrowScale), arrowScale = 1; end

    % Prepare Quiver Data
    X = Pre.Mesh.Nodes(Lds(:,1), 1);
    Y = Pre.Mesh.Nodes(Lds(:,1), 2);
    Z = Pre.Mesh.Nodes(Lds(:,1), 3);
    U = (Lds(:,2)==1) .* Lds(:,3);
    V = (Lds(:,2)==2) .* Lds(:,3);
    W = (Lds(:,2)==3) .* Lds(:,3);

    quiver3(X, Y, Z, U, V, W, 'r', 'LineWidth', 1.5, 'AutoSize', 'on');
    title('Applied Load Vectors');
else
    title('No Loads Applied');
end

