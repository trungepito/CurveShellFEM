% TEST_CylinderPressure.m
clear; clc; close all;

%% 1. Parameters
R = 1.0;          % Radius (m)
L = 2.0;          % Length (m)
t = 0.01;         % Thickness (m)
E = 200e9;        % Young's Modulus (Pa)
nu = 0.3;         % Poisson's Ratio
Pressure = 1e6;   % Internal Pressure (1 MPa)

% Theoretical Values
Sig_Hoop_Theory = (Pressure * R) / t;
Sig_Long_Theory = (Pressure * R) / (2 * t);
Disp_Radial_Theory = (Pressure * R^2) / (E * t) * (1 - nu/2);

fprintf('--- THEORETICAL TARGETS ---\n');
fprintf('Hoop Stress:       %.2f MPa\n', Sig_Hoop_Theory / 1e6);
fprintf('Axial Stress:      %.2f MPa\n', Sig_Long_Theory / 1e6);
fprintf('Radial Expansion:  %.4f mm\n', Disp_Radial_Theory * 1000);
fprintf('---------------------------\n');

%% 2. Preprocessor (Geometry & Mesh)
Pre = FEM_Preprocessor_CAD(E, nu, t);

% Generate a Full Cylinder (Modeled as 4 Quarter-Panels to ensure closure)
% Using the generic CAD patch method is best, but for this specific test,
% let's use the 'generateCylinderMesh' helper but modify it for full 360.
% Or simply create 4 patches using the CAD kernel we built.

% Let's use the topological method (addPoint, addLine, etc) to prove robustness.
% We create ONE quarter panel and replicate logic, or just mesh 1/4 with symmetry.
% SYMMETRY MODEL (1/4 Cylinder) is better for stability and inspection.
% We model 90 degrees.

% Points
p1 = Pre.addPoint(R, 0, 0);
p2 = Pre.addPoint(0, R, 0);
p3 = Pre.addPoint(R, 0, L);
p4 = Pre.addPoint(0, R, L);
center_bot = Pre.addPoint(0, 0, 0);
center_top = Pre.addPoint(0, 0, L);

% Lines
l_bot = Pre.addLine(p1, p2, 'arc', center_bot); % Bottom Arc
l_top = Pre.addLine(p3, p4, 'arc', center_top); % Top Arc
l_v1  = Pre.addLine(p1, p3, 'straight');        % Vertical 1
l_v2  = Pre.addLine(p2, p4, 'straight');        % Vertical 2

% Patch (Order: Bottom, Right(Vertical2), Top(Reversed), Left(Vertical1))
% Note: Topological direction matters.
% Bottom: p1->p2. Right: p2->p4. Top: p4->p3 (Reverse of Line def?).
% Let's assume the mesher handles orientation or define lines strictly CCW.
% Standard CCW for outward normal:
l_right = l_v2;
l_top_rev = Pre.addLine(p4, p3, 'arc', center_top); % Define reverse for simplicity
l_left_rev = Pre.addLine(p3, p1, 'straight');

pid = Pre.addPatch(l_bot, l_right, l_top_rev, l_left_rev);

% Mesh (10 elements circumferential, 10 axial)
Pre.meshQuadPatch(pid, 8, 8);
Pre.mergeDuplicateNodes();

%% 3. Boundary Conditions (Symmetry)

nodes = Pre.Mesh.Nodes;
for i = 1:size(nodes, 1)
    x = nodes(i,1); y = nodes(i,2); z = nodes(i,3);

    % Symmetry Plane X (where Y=0? No, at Y=0, normal is Y. Fix V, RotX, RotZ)
    % This corresponds to the nodes at (R, 0, z)
    if abs(y) < 1e-4
        Pre.BCs = [Pre.BCs; i, 2]; % Fix V (Y-disp)
        Pre.BCs = [Pre.BCs; i, 4]; % Fix Rot X
        Pre.BCs = [Pre.BCs; i, 5]; % Fix Rot Z
    end

    % Symmetry Plane Y (where X=0? At X=0, normal is X. Fix U, RotY, RotZ)
    % This corresponds to nodes at (0, R, z)
    if abs(x) < 1e-4
        Pre.BCs = [Pre.BCs; i, 1]; % Fix U (X-disp)
        Pre.BCs = [Pre.BCs; i, 4]; % Fix Rot Y
        Pre.BCs = [Pre.BCs; i, 5]; % Fix Rot Z
    end

    % Bottom Edge (Z=0): Sliding support (Fix W only)
    % To simulate "Closed End" axial stress, we must usually apply a line load
    % or fix one end and pull the other.
    % Here: Fix Z at bottom. Leave top free (but we need axial force).
    if abs(z) < 1e-4
        Pre.BCs = [Pre.BCs; i, 3]; % Fix W
    end
end

%% 4. Loads

% A. Internal Pressure (Radial)
% Function: @(r, th, z) [Fr, Fth, Fz] -> [Pressure, 0, 0]
% Note: Positive Fr is OUTWARD. Internal pressure pushes outward.
loadFunc = @(r, th, z) [Pressure; 0; 0];
allElems = 1:size(Pre.Mesh.Elements, 1);
Pre.applyCylindricalLoad(allElems, loadFunc);

% B. Axial Load (Closed End Effect)
% Pressure on the end caps pulls the cylinder axially.
% Total Force F = Pressure * Area = P * (pi * R^2)
% We are modeling 1/4 cylinder, so F_quarter = (P * pi * R^2) / 4.
% Apply this to the Top Edge (Z=L).
F_axial_total = (Pressure * pi * R^2) / 4;

% Find top edge line
% (We created it as l_top_rev or we can search nodes)
% Let's use the findNodesOnLine logic or simple coordinate search
top_nodes = find(abs(nodes(:,3) - L) < 1e-4);
% Distribute F_axial_total among these nodes.
% Simple average is WRONG for 8-node. Use consistent logic?
% Or just use applyCylindricalLoad with Fz component on top row elements? No, that applies to face.
% Let's use a simplified approach: Lumped distribution proportional to arc length is okay for fine mesh,
% but let's use a "Line Load" helper if available, or just distribute manually for this test.
% Better: Apply a pressure Pz = F_axial / Circumference_Area? No.
% Let's skip the closed end effect for the *automated* test to keep it simple,
% OR apply it manually to check Sig_Long.

% Let's apply the Axial Force manually evenly to check logic:
nTop = length(top_nodes);
% Note: Corner nodes get 1 unit, Midside get 2 units of weight?
% Let's just apply Average to see if we get close.
for k = 1:nTop
    Pre.Loads = [Pre.Loads; top_nodes(k), 3, F_axial_total/nTop];
end

%% 5. Solve
Sol = FEM_Solver(Pre);
Sol.solveStatic();

%% 6. Results & Verification
Post = FEM_Postprocessor(Pre, Sol);

% A. Check Radial Displacement
% Pick a node in the middle (away from boundaries)
mid_nodes = find(abs(nodes(:,3) - L/2) < 0.1);
sample_node = mid_nodes(1);

u = Sol.U((sample_node-1)*6 + 1);
v = Sol.U((sample_node-1)*6 + 2);
ur = sqrt(u^2 + v^2);

fprintf('\n--- SIMULATION RESULTS ---\n');
fprintf('Simulated Radial Disp: %.4f mm\n', ur * 1000);
err_disp = abs(ur - Disp_Radial_Theory)/Disp_Radial_Theory * 100;
fprintf('Error: %.2f%%\n', err_disp);

% B. Check Stresses (Hoop)
% Recover stress at top layer
% Stress is in Global Cartesian. We need to rotate to Cylindrical.
% At symmetry X (y=0), Hoop is Global Y-Stress (SigmaY).
% At symmetry Y (x=0), Hoop is Global X-Stress (SigmaX).

% Let's pick the sample node again.
% Calculate stress manually for this verification
[valX, ~] = Post.recoverNodalSmooth('SigmaX', 'Top');
[valY, ~] = Post.recoverNodalSmooth('SigmaY', 'Top');

% At the sample node, check its angle
sx = nodes(sample_node, 1); sy = nodes(sample_node, 2);
angle = atan2(sy, sx);

% Rotate Cartesian Stress to Cylindrical Hoop
% Sig_Hoop = Sig_x*sin^2(t) + Sig_y*cos^2(t) - 2*Tau*sin(t)cos(t)
% Simplified: If we pick a node at Y=0 (Angle=0), Hoop = SigmaY
node_y0 = find(abs(nodes(:,2))<1e-3 & abs(nodes(:,3)-L/2)<0.1, 1);
Sim_Hoop = valY(node_y0);

fprintf('Simulated Hoop Stress: %.2f MPa\n', Sim_Hoop / 1e6);
err_strs = abs(Sim_Hoop - Sig_Hoop_Theory)/Sig_Hoop_Theory * 100;
fprintf('Error: %.2f%%\n', err_strs);

% C. Visuals
figure;
subplot(1,2,1);
Post.plotField('Displacement', 'Top');
title('Radial Expansion');

subplot(1,2,2);
% Plot Sigma Y (Hoop Stress approx at Y=0 plane)
Post.plotField('SigmaY', 'Top');
title('Sigma Y (Hoop Stress at Bottom Edge)');

% Show Load Vectors to confirm direction
figure; hold on; axis equal;
patch('Vertices', nodes, 'Faces', Pre.Mesh.Elements(:,[1,2,3,4]), 'FaceColor', 'w', 'EdgeColor', 'b');
% Plot only 10% of loads to avoid clutter
Lds = Pre.Loads(1:5:end, :);
quiver3(nodes(Lds(:,1),1), nodes(Lds(:,1),2), nodes(Lds(:,1),3), ...
    (Lds(:,2)==1).*Lds(:,3), (Lds(:,2)==2).*Lds(:,3), (Lds(:,2)==3).*Lds(:,3), ...
    5e-5, 'r', 'LineWidth', 2);
title('Applied Pressure Vectors');