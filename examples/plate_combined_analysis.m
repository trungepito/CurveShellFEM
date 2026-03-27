% plate_combined_analysis.m
%
% Simply supported square plate under combined loading:
%   - Distributed transverse pressure  q  (Z direction, perpendicular to plate)
%   - Membrane displacement             u_x (X direction, prescribed in-plane)
%
% Two analyses are performed and compared:
%   1. Arc-length solver (Riks)   -- handles transverse pressure nonlinearity
%   2. Adaptive GNI solver        -- stage-based with displacement control
%
% Boundary conditions (simply supported on all 4 edges):
%   All edges:  w = 0  (no transverse displacement)
%   All edges:  rotations about in-plane axes constrained (Mx = My = 0)
%               i.e. DOF 4 and 5 fixed to 0 on all edge nodes
%   In-plane:   edges free to slide in-plane except where membrane load
%               is applied (X=0 face fixed in X; X=1 face prescribed)
%
% Physical parameters:
%   Lx = Ly = 1.0 m,  t = 10 mm,  E = 200 GPa,  nu = 0.3
%   Pressure  q    = 10 kPa (uniform, applied as distributed load)
%   Membrane  u_x  = 0.005 m (2*t, well into geometric nonlinear range)

clear; clc; close all;
fprintf('============================================================\n');
fprintf('  COMBINED PLATE ANALYSIS — Geometric Nonlinearity\n');
fprintf('============================================================\n');

%% =========================================================
%  1.  GEOMETRY AND MATERIAL
% ==========================================================
E  = 200e9;   % Young's modulus [Pa]
nu = 0.3;     % Poisson ratio
t  = 0.010;   % Thickness [m]  (10 mm)
Lx = 1.0;     % Plate length in X [m]
Ly = 1.0;     % Plate length in Y [m]

Pre = FEM_Preprocessor_v2(E, nu, t);

% Plate in XY plane, Z is the transverse direction
Pre.createPlate([0, 0, 0], Lx, Ly);

% 2. Material: J2 Plasticity
sigY = 180e6; % Yield Stress
H_mod = 20e9;  % Hardening
Pre.setMaterialPlastic(sigY, H_mod);

% Mesh: 6 x 6 elements (sufficient for convergence, keeps runtime short)
nEl = 20;
Pre.meshAllPatches(nEl, nEl);
Pre.computeNormals();

fprintf('Mesh: %d x %d elements, %d nodes, %d DOFs\n', ...
    nEl, nEl, size(Pre.Mesh.Nodes,1), size(Pre.Mesh.Nodes,1)*6);

%% =========================================================
%  2.  NODE SELECTION
% ==========================================================
tol = 1e-4;

% All four edges (for simply supported condition)
edgeX0   = Pre.selectNodesOnPlane(1, 0,  tol);   % X = 0
edgeXL   = Pre.selectNodesOnPlane(1, Lx, tol);   % X = Lx
edgeY0   = Pre.selectNodesOnPlane(2, 0,  tol);   % Y = 0
edgeYL   = Pre.selectNodesOnPlane(2, Ly, tol);   % Y = Ly
allEdges = unique([edgeX0; edgeXL; edgeY0; edgeYL]);

% Centre node (for monitoring deflection)
% Find node closest to (Lx/2, Ly/2, 0)
nodeCoords = Pre.Mesh.Nodes;
d2centre   = (nodeCoords(:,1)-Lx/2).^2 + (nodeCoords(:,2)-Ly/2).^2;
[~, centreID] = min(d2centre);
fprintf('Centre monitor node: %d  at (%.3f, %.3f)\n', ...
    centreID, nodeCoords(centreID,1), nodeCoords(centreID,2));

%% =========================================================
%  3.  BOUNDARY CONDITIONS
%
%  Simply supported  =>  w = 0 (DOF 3) and bending rotations = 0
%  DOF convention in Curve8Element (6-DOF global):
%    1=Ux, 2=Uy, 3=Uz(=w), 4=Rx, 5=Ry, 6=Rz(drilling, penalised)
%
%  For a simply-supported edge:
%    Uz = 0      (DOF 3) -- no transverse deflection
%    The rotation perpendicular to the edge = 0:
%      X-parallel edges (Y=0, Y=Ly): Rx = DOF 4 = 0
%      Y-parallel edges (X=0, X=Lx): Ry = DOF 5 = 0
%
%  In-plane (membrane) BCs:
%    X=0 edge: Ux = 0  (fixed reference for membrane stretching)
%    Y=0 edge: Uy = 0  (one line to prevent rigid body in Y)
%    X=Lx edge: Ux = u_x_prescribed  (applied via displacement stage)
% ==========================================================

u_x_prescribed = 0.005;   % 0.5 % strain = well into GNI range  [m]
q_pressure     = 1000e3;    % Uniform transverse pressure [Pa]

% --- Simply supported: transverse + bending rotations on all edges ---
Pre.addBC(allEdges, 3, 0, 'SS_w');           % w = 0 on all edges

% Rotation about edge-parallel axis = 0 (simply supported, not clamped)
Pre.addBC([edgeY0; edgeYL], 4, 0, 'SS_Rx'); % X-parallel edges: Rx = 0
Pre.addBC([edgeX0; edgeXL], 5, 0, 'SS_Ry'); % Y-parallel edges: Ry = 0

% --- In-plane membrane BCs ---
Pre.addBC(edgeX0, 1, 0, 'Mem_fixed');        % Ux = 0 at X=0
Pre.addBC(edgeY0, 2, 0, 'Mem_Uy');           % Uy = 0 prevents RBM in Y

% --- Prescribed membrane displacement (applied in Stage 1) ---
Pre.addBC(edgeXL, 1, u_x_prescribed, 'Mem_disp');   % Ux = u_x at X=Lx

% --- Transverse pressure load (unit pressure; lambda scales it) ---
% addPressureLoad integrates q*n over elements.
% Since the plate normal points in +Z, a positive magnitude pushes in +Z.
% We want downward (-Z) loading, so magnitude = -q_pressure.
allElems = (1:size(Pre.Mesh.Elements,1))';
Pre.addPressureLoad(allElems, -q_pressure, 'Pressure');

%% =========================================================
%  4a.  ARC-LENGTH ANALYSIS  (Riks constraint)
%       Stage 1: Apply membrane displacement (in-plane loading)
%       Stage 2: Apply transverse pressure incrementally via arc-length
% ==========================================================
fprintf('\n--- Analysis 1: Arc-Length (Riks) ---\n');

opts_arc         = SolverOptions();
opts_arc.Tolerance     = 1e-4;
opts_arc.MaxIterations = 25;
opts_arc.InitialDt     = 0.1;
opts_arc.MaxDt         = 1.0;
opts_arc.MinDt         = 1e-4;

SolArc = FEM_Solver_ArcLength(Pre, opts_arc);

% Stage 1 — Apply membrane in-plane displacement (quasi-static, single step)
% Use LoadControl so we ramp Ux from 0 to u_x_prescribed in one arc-length
% increment: arc_length = 1.0 = full load factor in one step.
S_arc1 = LoadingStage(1.0);
S_arc1.activateBC('SS_w');
S_arc1.activateBC('SS_Rx');
S_arc1.activateBC('SS_Ry');
S_arc1.activateBC('Mem_fixed');
S_arc1.activateBC('Mem_Uy');
S_arc1.activateBC('Mem_disp');     % Ramps Ux to u_x_prescribed
S_arc1.ConstraintType  = 'DispControl';
S_arc1.ControlDOF      = (edgeXL(1) - 1)*6 + 1;   % Ux at first X=Lx node
S_arc1.ArcLengthRadius = 0.5;
S_arc1.ArcLengthMin    = 0.05;
S_arc1.ArcLengthMax    = 1.0;

% Stage 2 — Riks arc-length on transverse pressure
% Lambda goes from 0 to 1 (full pressure = q_pressure)
S_arc2 = LoadingStage(1.0);
S_arc2.activateBC('SS_w');
S_arc2.activateBC('SS_Rx');
S_arc2.activateBC('SS_Ry');
S_arc2.activateBC('Mem_fixed');
S_arc2.activateBC('Mem_Uy');
% S_arc2.activateBC('Mem_disp');     % Hold membrane displacement fixed
S_arc2.activateLoad('Pressure');
S_arc2.ConstraintType  = 'Riks';
S_arc2.ArcLengthRadius = 0.04;
S_arc2.ArcLengthMin    = 5e-4;
S_arc2.ArcLengthMax    = 0.2;

SolArc.solve({S_arc2});

%% =========================================================
%  4b.  ADAPTIVE GNI ANALYSIS  (FEM_Solver_Adaptive)
%       Stage 1: Membrane displacement ramp
%       Stage 2: Pressure ramp (proportional loading)
% ==========================================================
fprintf('\n--- Analysis 2: Adaptive GNI Solver ---\n');

opts_ada = SolverOptions();
opts_ada.Tolerance     = 1e-4;
opts_ada.MaxIterations = 20;
opts_ada.InitialDt     = 0.1;
opts_ada.MaxDt         = 0.5;
opts_ada.MinDt         = 1e-4;
opts_ada.MaxBisections = 6;

SolAda = FEM_Solver_Adaptive(Pre, opts_ada);

% Stage 1 — Membrane displacement (same BCs as arc-length Stage 1)
S_ada1 = LoadingStage(1.0);
S_ada1.activateBC('SS_w');
S_ada1.activateBC('SS_Rx');
S_ada1.activateBC('SS_Ry');
S_ada1.activateBC('Mem_fixed');
S_ada1.activateBC('Mem_Uy');
S_ada1.activateBC('Mem_disp');

% Stage 2 — Transverse pressure (proportional, adaptive time stepping)
S_ada2 = LoadingStage(1.0);
S_ada2.activateBC('SS_w');
S_ada2.activateBC('SS_Rx');
S_ada2.activateBC('SS_Ry');
S_ada2.activateBC('Mem_fixed');
S_ada2.activateBC('Mem_Uy');
% S_ada2.activateBC('Mem_disp');
S_ada2.activateLoad('Pressure');

SolAda.solve({S_ada2});

%% =========================================================
%  5.  POST-PROCESSING
% ==========================================================
c_dof_w  = (centreID - 1)*6 + 3;   % Centre node DOF for w (Z)
c_dof_ux = (centreID - 1)*6 + 1;   % Centre node DOF for Ux

%% --- 5.1  Final deformed shape (Adaptive GNI, end of Stage 2) ---
PostAda = FEM_Postprocessor(Pre, SolAda);

figure('Name','Final Deformed Shape — Adaptive GNI','Color','w','Position',[50 50 900 500]);
opts_post.layer = 'Top';
opts_post.scale = 20;   % Exaggeration factor for visualisation
opts_post.Nummode = 1;
PostAda.plotField('Displacement', opts_post);
title(sprintf('Displacement magnitude — combined loading (scale ×%d)', opts_post.scale));
colormap jet;

%% --- 5.2  Von Mises stress (top surface) ---
figure('Name','Von Mises — Top Surface','Color','w','Position',[100 100 900 500]);
PostAda.plotField('VonMises', opts_post);
title('Von Mises stress — top surface');
colormap jet;

%% --- 5.3  Load-displacement curves: centre deflection vs pressure factor ---
figure('Name','Load–Displacement Curve','Color','w','Position',[150 150 800 500]);
hold on; grid on; box on;

% Arc-length: extract only Stage 2 data (after membrane step)
if ~isempty(SolArc.U_Hist) && ~isempty(SolArc.LambdaHist)
    n_arc_tot = size(SolArc.U_Hist, 2);
    % Stage 2 starts after Stage 1 converged; lambda resets per stage so
    % use LambdaHist which is accumulated across stages.
    w_arc   = SolArc.U_Hist(c_dof_w, :);
    lam_arc = SolArc.LambdaHist;
    % Only plot positive lambda (pressure stage)
    idx_pres = lam_arc > 1e-6;
    if any(idx_pres)
        plot(w_arc(idx_pres)*1000, lam_arc(idx_pres), ...
            'b-o', 'LineWidth', 2, 'MarkerSize', 4, ...
            'DisplayName', sprintf('Arc-length/Riks (%d steps)', sum(idx_pres)));
    end
end

% Adaptive: extract Stage 2 steps (second half of U_Hist)
if ~isempty(SolAda.U_Hist)
    w_ada   = SolAda.U_Hist(c_dof_w, :);
    % Reactions stored per stage in ReactionHist cell
    % Use displacement history length as proxy; time axis from History_Time
    n_ada = size(SolAda.U_Hist, 2);
    t_ada = SolAda.History_Time(1:n_ada);
    % Stage 2 time > 1.0 (Stage 1 runs 0..1, Stage 2 runs 1..2)
    idx_s2 = t_ada > 1.0;
    if any(idx_s2)
        % Normalise time within stage 2 to [0,1] as proxy for lambda
        t_s2 = t_ada(idx_s2) - 1.0;
        plot(w_ada(idx_s2)*1000, t_s2, ...
            'r--s', 'LineWidth', 2, 'MarkerSize', 5, ...
            'DisplayName', sprintf('Adaptive GNI (%d steps)', sum(idx_s2)));
    end
end

%% Navier analytical solution for reference (linear, no membrane prestress)
% w_centre = (16*q*a^4)/(pi^6 * D) * sum_mn (1/(m^2+n^2)^2)
% First term (m=n=1): w_centre ≈ 0.00406 * q * a^4 / D
D_plate = E * t^3 / (12 * (1 - nu^2));
w_navier_linear = 0.00406 * q_pressure * Lx^4 / D_plate;
yline(1.0, 'k:', 'LineWidth', 1, 'DisplayName', ...
    sprintf('Full pressure (q=%.0f kPa)', q_pressure/1e3));
xline(w_navier_linear*1000, 'k--', 'LineWidth', 1, 'DisplayName', ...
    sprintf('Linear Navier w_{centre}=%.2f mm', w_navier_linear*1000));

xlabel('Centre deflection w (mm)', 'FontSize', 12);
ylabel('Pressure load factor \lambda (0 = zero, 1 = full q)', 'FontSize', 12);
title('Plate centre deflection vs pressure load factor', 'FontSize', 13);
legend('Location', 'northwest');

%% --- 5.4  Membrane + bending interaction: Ux at centre vs w ---
figure('Name','Membrane–Bending Interaction','Color','w','Position',[200 200 800 450]);
hold on; grid on; box on;

if ~isempty(SolArc.U_Hist)
    ux_arc = SolArc.U_Hist(c_dof_ux, :);
    w_arc  = SolArc.U_Hist(c_dof_w,  :);
    plot(ux_arc*1000, w_arc*1000, 'b-o', 'LineWidth', 2, 'MarkerSize', 4, ...
        'DisplayName', 'Arc-length path');
end
if ~isempty(SolAda.U_Hist)
    ux_ada = SolAda.U_Hist(c_dof_ux, :);
    w_ada2 = SolAda.U_Hist(c_dof_w,  :);
    plot(ux_ada*1000, w_ada2*1000, 'r--s', 'LineWidth', 2, 'MarkerSize', 5, ...
        'DisplayName', 'Adaptive GNI path');
end

xlabel('Centre in-plane displacement u_x (mm)', 'FontSize', 12);
ylabel('Centre transverse deflection w (mm)', 'FontSize', 12);
title('Membrane–bending interaction at plate centre', 'FontSize', 13);
legend('Location', 'best');

%% --- 5.5  Arc-length adaptive radius history ---
figure('Name','Arc-Length Radius History','Color','w','Position',[250 250 700 350]);
if ~isempty(SolArc.ArcLengthHistory)
    semilogy(SolArc.ArcLengthHistory, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    xlabel('Converged step','FontSize',12);
    ylabel('Arc-length radius','FontSize',12);
    title('Adaptive arc-length radius per step','FontSize',13);
    grid on;
end

%% --- 5.6  Summary printout ---
fprintf('\n============================================================\n');
fprintf('  RESULTS SUMMARY\n');
fprintf('============================================================\n');
fprintf('Plate:   %.1f x %.1f m,  t = %.0f mm\n', Lx, Ly, t*1000);
fprintf('Material: E = %.0f GPa,  nu = %.2f\n', E/1e9, nu);
fprintf('Pressure: q = %.0f kPa (full)\n', q_pressure/1e3);
fprintf('Membrane: u_x = %.1f mm (prescribed at X=Lx)\n', u_x_prescribed*1000);
fprintf('Navier linear solution: w_centre = %.3f mm\n', w_navier_linear*1000);

if ~isempty(SolArc.U_Hist)
    w_arc_final = SolArc.U_Hist(c_dof_w, end) * 1000;
    fprintf('\nArc-length solver:\n');
    fprintf('  Total converged steps:  %d\n', SolArc.StepCount);
    fprintf('  Final centre w:         %.3f mm\n', w_arc_final);
    fprintf('  Ratio to linear:        %.3f\n', w_arc_final / (w_navier_linear*1000));
end

if ~isempty(SolAda.U_Hist)
    w_ada_final = SolAda.U_Hist(c_dof_w, end) * 1000;
    fprintf('\nAdaptive GNI solver:\n');
    fprintf('  Total converged steps:  %d\n', SolAda.StepCount);
    fprintf('  Final centre w:         %.3f mm\n', w_ada_final);
    fprintf('  Ratio to linear:        %.3f\n', w_ada_final / (w_navier_linear*1000));
end

fprintf('\nNote: w/t ratio = %.2f — large deflection effects are significant.\n', ...
    abs(SolAda.U_Hist(c_dof_w, end)) / t);
fprintf('============================================================\n');

%% --- 5.7  Optional: App GUI (uncomment if GUI is available) ---
 PostAda.plotReactionDispCurve(centreID, 3);
% app = FEM_Postprocessor_App(PostArc);
