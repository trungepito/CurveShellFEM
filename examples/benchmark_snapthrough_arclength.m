% benchmark_snapthrough_arclength.m
%
% Shallow-arch snap-through using the FEM_Solver_ArcLength.
% Compares three constraint types (Riks, LoadControl, DispControl) against
% the existing displacement-control solver on the same geometry.
%
% This is the standard benchmark for validating arc-length solvers:
% the structure has a limit point (positive stiffness -> zero -> negative),
% which displacement control can track but load control cannot.
% The Riks method should trace the complete equilibrium path automatically.

clear; clc; close all;

% ------------------------------------------------------------------
% 1.  Geometry and material
% ------------------------------------------------------------------
E = 200e9; nu = 0.3; t = 0.05;
Pre = FEM_Preprocessor_v2(E, nu, t);

R = 6.0;  Chord = 10.0;
H = sqrt(R^2 - (Chord/2)^2);

n1 = [-Chord/2, 0, 0];
n2 = [ Chord/2, 0, 0];
n_center = [0, 0, -H];

nodes = [n1; n2; n_center];
segs  = [1, 2, 3, 12];

direction = [0, 1, 0];
Length    = 6;
Pre.createExtrusion(nodes, segs, direction, Length, 9);

% ------------------------------------------------------------------
% 2.  Boundary conditions
% ------------------------------------------------------------------
leftNodes  = Pre.selectNodesByBox(-Chord/2-0.1, -Chord/2+0.1, -1, 1, -1, 1);
rightNodes = Pre.selectNodesByBox( Chord/2-0.1,  Chord/2+0.1, -1, 1, -1, 1);
Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Support');

% Control node: peak of the arch
centerID = Pre.selectNodesByBox(-0.1, 0.1, 2.9, 3.1, R-H-0.1, R-H+0.1);
centerID = centerID(1);

% Reference load at the crown (unit load; lambda scales it)
Pre.addNodalLoad(centerID, 3, -1e5, 'CrownLoad');

% ------------------------------------------------------------------
% 3.  Arc-Length solver — Riks constraint (traces limit point)
% ------------------------------------------------------------------
opts = SolverOptions();
opts.Tolerance     = 1e-4;
opts.MaxIterations = 30;

SolArc = FEM_Solver_ArcLength(Pre, opts);

S_riks = LoadingStage(1.0);
S_riks.activateBC('Support');
S_riks.activateLoad('CrownLoad');
S_riks.ConstraintType  = 'Riks';
S_riks.ArcLengthRadius = 0.02;
S_riks.ArcLengthMin    = 1e-5;
S_riks.ArcLengthMax    = 0.25;

fprintf('\n=== Arc-Length Analysis (Riks) ===\n');
SolArc.solve({S_riks});

% ------------------------------------------------------------------
% 4.  Reference: displacement-control (for comparison curve)
% ------------------------------------------------------------------
target_disp = -1.8;
Pre.addBC(centerID, 3, target_disp, 'DispControl');
optsDC = SolverOptions(); optsDC.Tolerance=1e-4; optsDC.InitialDt=1/30; optsDC.MaxIterations=15;
SolDC = FEM_Solver_Adaptive(Pre, optsDC);
S_dc = LoadingStage(1.0);
S_dc.activateBC('Support'); S_dc.activateBC('DispControl');
fprintf('\n=== Displacement-Control Reference ===\n');
SolDC.solve({S_dc});

%% ------------------------------------------------------------------
% 5.  Post-processing
% ------------------------------------------------------------------
c_idx = (centerID-1)*6 + 3;

figure('Name', 'Snap-Through: Arc-Length vs Displacement Control', 'Color', 'w');
hold on; grid on;

% Arc-length path
if ~isempty(SolArc.U_Hist)
    u_arc = SolArc.U_Hist(c_idx, :);
    % Scale lambda back to force: lambda * 1e6 N
    f_arc = SolArc.LambdaHist * 1e6;
    plot(u_arc, f_arc/1e3, 'b-o', 'LineWidth', 2, 'MarkerSize', 4, ...
        'DisplayName', sprintf('Arc-Length / Riks (%d steps)', SolArc.StepCount));
end

% Displacement-control path
if ~isempty(SolDC.U_Hist)
    f_dc = cell2mat(SolDC.ReactionHist);
    u_dc = SolDC.U_Hist(c_idx, end-size(f_dc,2)+1:end);
    plot(u_dc, -f_dc(end, :)/1e3, 'r--', 'LineWidth', 1.5, ...
        'DisplayName', 'Displacement control');
end

xlabel('Crown Z-displacement (m)');
ylabel('Applied force (kN)');
title('Shallow arch snap-through — equilibrium path');
legend('Location', 'best');

% ------------------------------------------------------------------
% 6.  Arc-length radius history
% ------------------------------------------------------------------
figure('Name', 'Arc-Length Radius Adaptation', 'Color', 'w');
if ~isempty(SolArc.ArcLengthHistory)
    semilogy(SolArc.ArcLengthHistory, 'b-o', 'LineWidth', 1.5);
    xlabel('Step'); ylabel('Arc-length radius');
    title('Adaptive arc-length radius history'); grid on;
end

fprintf('\nArc-length solver finished: %d steps converged.\n', SolArc.StepCount);
fprintf('Displacement-control finished: %d steps converged.\n', ...
    size(SolDC.U_Hist, 2));

%% 5. Post-Process
Post = FEM_Postprocessor(Pre, SolDC);

% A. Plot Curve
% Plot Displacement of a tip node (e.g., center of tip)
% midTip = tipNodes(round(end/2));
% Post.plotLoadDisplacement(web0(1), 3); % Z-disp
opts1.layer='Top';
opts1.scale=1;
opts1.Nummode=1;
Post.plotField('Displacement', opts1);
title('Snapthough examples');