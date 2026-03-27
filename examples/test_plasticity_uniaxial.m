% test_plasticity_uniaxial.m
% Verification of J2 Plasticity with Isotropic Hardening
clear; clc; close all;

% 1. Create a single element model
E = 200e9; nu = 0.3; t = 0.01;
sigY = 400e6; H = 10e9; % Linear Hardening

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.setMaterialPlastic(sigY, H);

% Create a single 1x1 meter element
% Keypoints
Pre.addKeypoint(0, 0, 0);
Pre.addKeypoint(1, 0, 0);
Pre.addKeypoint(1, 1, 0);
Pre.addKeypoint(0, 1, 0);
% Lines
Pre.addLine(1, 2, 'straight');
Pre.addLine(2, 3, 'straight');
Pre.addLine(3, 4, 'straight');
Pre.addLine(4, 1, 'straight');
% Patch & Mesh
Pre.addPatch(1, 2, 3, 4);
Pre.meshAllPatches(1, 1);
Pre.computeNormals();

% 2. Boundary Conditions (Uniaxial Tension)
% Fix Left edge (x=0)
nodes_left = Pre.selectNodesOnPlane(1, 0, 0.01);
Pre.addBC(nodes_left, [1, 2, 3, 4, 5, 6], 0, 'Fix');

% Displacement Control on Right edge (x=1)
nodes_right = Pre.selectNodesOnPlane(1, 1, 0.01);
% We pull Node 2 and Node 5 (middle) and Node 3
target_disp = 0.01; % 1% strain (well into plastic regime)

% 3. Solve
controlNode = nodes_right(1);
Pre.addBC(controlNode, 1, target_disp, 'Tip_Disp');
opts = SolverOptions(); opts.Tolerance=1e-6; opts.InitialDt=1/20; opts.MaxIterations=10;
Sol = FEM_Solver_Adaptive(Pre, opts);
S1 = LoadingStage(1.0); S1.activateBC('Fix'); S1.activateBC('Tip_Disp');
Sol.solve({S1});

%% 4. Post-Process & Verify
Post = FEM_Postprocessor(Pre, Sol);

% Plot Force-Displacement
figure('Name', 'Plasticity Verification');
Post.plotReactionDispCurve(controlNode, 1);
grid on; hold on;

% Analytical Solution
eps_yield = sigY / E;
u_yield = eps_yield * 1.0; % Length = 1m
u_range = linspace(0, target_disp, 100);
f_anal = zeros(size(u_range));
for i = 1:length(u_range)
    u_curr = u_range(i);
    if u_curr <= u_yield
        sig = E * u_curr;
    else
        sig = sigY + H * (u_curr - u_yield);
    end
    f_anal(i) = sig * (1.0 * t); % Force = Stress * Area (1m x t)
end
plot(u_range, f_anal, 'b--', 'LineWidth', 2);
legend('CurveShellFEM (Plastic)', 'Analytical Solution');
title('Uniaxial Tension: J2 Plasticity Verification');
% saveas(gcf, 'd:\Works\2025 Industry Project\CurveShellFEM\docs\plasticity_verification.png');

% 5. App Visualization
app = FEM_Postprocessor_App(Post);
