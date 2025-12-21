% TEST_FlatPlate_SS.m
clear; clc; close all;
tic
%% 1. Problem Parameters
L = 1;            % Side Length (m)
t = 0.01;           % Thickness (m)
E = 200e9;          % Young's Modulus (Pa)
nu = 0.3;           % Poisson's Ratio
q = -10000;          % Uniform Load (Pa)

% Theoretical Solution (Navier's Solution for SS Plate)
% w_max = alpha * q * L^4 / D
% D = E*t^3 / (12*(1-nu^2))
% alpha for square plate approx 0.00406
D = (E * t^3) / (12 * (1 - nu^2));
alpha = 0.004062;
w_theory = alpha * q * L^4 / D;

fprintf('--- BENCHMARK: Simply Supported Square Plate ---\n');
fprintf('Theoretical Max Deflection: %.6f mm\n', w_theory * 1000);

%% 2. Preprocessor
Pre = FEM_Preprocessor(E, nu, t);

% Generate Mesh (10x10 Elements)
% Sufficient for 8-node convergence
Pre.generateFlatPlate(L, L, 20, 20);

%% 3. Boundary Conditions (Simple Support)
% Nodes are at X=0, X=L, Y=0, Y=L.
% For "Pinned" support in Shell FEA:
% Fix Translations (u,v,w). Free Rotations (theta_x, theta_y, theta_z).
% Note: Fixing u,v prevents rigid body motion and implies membrane is pinned.

nodes = Pre.Mesh.Nodes;
tol = 1e-5;

for i = 1:size(nodes, 1)
    x = nodes(i,1);
    y = nodes(i,2);

    is_boundary = (abs(x) < tol) || (abs(x-L) < tol) || ...
        (abs(y) < tol) || (abs(y-L) < tol);

    if is_boundary
        % Fix U, V, W (DOFs 1, 2, 3)
        % Pre.addConstraint(i, 1);
        Pre.addConstraint(i, 2);
        Pre.addConstraint(i, 3);

        % NOTE: For "Hard" simple support, we often leave rotations free.
        % However, to prevent drilling singularities on the edge if the
        % drilling stiffness isn't robust, some codes fix normal rotation.
        % With our updated 6-DOF solver + Drilling Stabilization,
        % we can safely leave rotations free!
    end
    is_boundary = (abs(y) < tol) || (abs(y-L) < tol);
    if is_boundary
        % Fix U, V, W (DOFs 1, 2, 3)
        Pre.addConstraint(i, 1);
        % Pre.addConstraint(i, 2);
        % Pre.addConstraint(i, 3);
    end

end

%% 4. Loads
% Apply uniform pressure in Z (DOF 3)
for i = 1:size(nodes,1)
    if abs(nodes(i,1))<=tol
        Pre.addLoad(i, 1, 100000); % 1000N in X
    end
    if abs(nodes(i,1)-max(nodes(:,1)))<=tol
        Pre.addLoad(i, 1, -100000); % 1000N in X
    end
end
Pre.applyUniformPressure([0, 0, q]);
% 
%% 5. Solution
Sol = FEM_Solver(Pre);
Sol.solveStatic();
% Sol.solveBuckling(10);
% SolNLopt.numLoadSteps=20;
% SolNLopt.maxIter = 100; 
% SolNLopt.tol = 1e-6;
% SolNLopt.linesearch=0;
% 
% Sol2=FEM_Solver_NL(Pre);
% Sol2.solveNonLinear(SolNLopt);
toc

%% 6. Validation
% Find Center Node (Max Deflection)
dist_to_center = vecnorm(nodes - [L/2, L/2, 0], 2, 2);
[~, centerNodeID] = min(dist_to_center);

% Get Z-displacement (DOF 3)
% Sol.U is structured as [u1, v1, w1, tx1, ty1, tz1, u2...]
% U=Sol2.U
% try
    w_fem1 = Sol.U((centerNodeID-1)*6 + 3 );
% catch
    w_fem2 = Sol2.U((centerNodeID-1)*6 + 3 );
% end


fprintf('FEM Max Deflection:         %.6f mm [Linear]\n', w_fem1 * 1000);
error_pct = abs((w_fem1 - w_theory)/w_theory) * 100;
fprintf('Error:                      %.2f%%\n', error_pct);

fprintf('FEM Max Deflection:         %.6f mm [Nonlinear]\n', w_fem2 * 1000);
error_pct = abs((w_fem2 - w_theory)/w_theory) * 100;
fprintf('Error:                      %.2f%%\n', error_pct);

%% 7. Visualization
Post = FEM_Postprocessor(Pre, Sol);
opts.layer='Mid';
opts.scale=0.5;
opts.Nummode=2;
% Plot Z-Displacement
% figure;
Post.plotField('Displacement', opts);
title('Displacement Magnitude');
view(3);

% Plot Stress (Sigma X at Top Surface)
% Should be compression in center-top
Post.plotField('SigmaX', opts);
title('Bending Stress \sigma_x (Top)');
colormap jet;
% for iii=1:10
%     opts.Nummode=iii;
% Post.plotField('Buckling', opts);
% title('VonMises Stress \sigma_{eqv} (Bot)');
% colormap jet;
% end
% Plot Centerline Deflection
% figure;
% y_mid_nodes = find(abs(nodes(:,2) - L/2) < 0.01);
% [~, sortIdx] = sort(nodes(y_mid_nodes, 1));
% sortedNodes = y_mid_nodes(sortIdx);

% x_vals = nodes(sortedNodes, 1);
% z_vals = Sol.U((sortedNodes-1)*6 + 3);
%%
% plot(x_vals, z_vals, 'r-o', 'LineWidth', 2);
% hold on;
% y_theory_curve = (w_theory / 0.004062) * 0.00406 * sin(pi*x_vals/L); % Approx Sine profile
% plot(x_vals, y_theory_curve, 'b--');
% grid on;
% legend('FEM', 'Theory (Approx Sine)');
% title('Centerline Deflection (Y = 0.5)');
% xlabel('X Position (m)');
% % ylabel('Vertical Deflection (m)');
Post2 = FEM_Postprocessor(Pre, Sol2);
% 
% % A. Plot Curve
% Plot Displacement of a tip node (e.g., center of tip)
% midTip = tipNodes(round(end/2));
Post2.plotLoadDisplacement(centerNodeID, 3); % Z-disp

Post2.plotField('Displacement', opts);
title('Displacement Magnitude NL');
view(3);
%%
Post2.animateScenario(centerNodeID, 3, 3, 0.5);