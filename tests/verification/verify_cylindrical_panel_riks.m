function result = verify_cylindrical_panel_riks()
% VERIFY_CYLINDRICAL_PANEL_RIKS  Crisfield (1981) snap-through benchmark.
%
% VT4.1  Apply geometric imperfection from first buckling mode scaled to t/100.
% VT4.2  Run RiksStrategy arc-length analysis.
% VT4.3  Reference peak load: P_cr = 640 N (Crisfield 1981, Table 1).
% VT4.4  PASS: |P_peak - 640| / 640 < 0.05 (5% tolerance).
% VT4.5  Snap-through must be captured: min(diff(LambdaHist)) < 0.
%
% Geometry: R=2540mm, L=508mm, t=12.7mm, half-angle=0.1rad.
% Material:  E=3102.75 N/mm2 (3.10275e9 Pa), nu=0.3.
% Loading:   central point load P (downward).
% Reference: Crisfield (1981) "A fast incremental/iterative solution procedure
%            that handles snap-through", Comp & Struct, Table 1.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('verify_cylindrical_panel_riks');

result = run_subtest(result, 'VT4.1-VT4.5 Crisfield panel snap-through', ...
    @() run_crisfield_panel());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_crisfield_panel()
% Crisfield (1981) parameters — SI units (Pa, m)
R    = 2.540;        % m
L    = 0.508;        % m
t    = 0.0127;       % m
ang  = 0.1;          % half-angle in radians
E    = 3.10275e9;    % Pa
nu   = 0.3;
P_ref = 640.0;       % N reference peak load

fprintf('  [Crisfield] R=%g m, L=%g m, t=%g m, E=%g Pa\n', R, L, t, E);
fprintf('  [Crisfield] Reference peak load P_cr = %g N\n', P_ref);

% ----------------------------------------------------------------
% VT4.1  Build model and apply imperfection
% ----------------------------------------------------------------
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createCylinderPanel(R, L, -ang, ang);
Pre.meshAllPatches(4, 4);

nNodes = size(Pre.Mesh.Nodes, 1);
nodes  = Pre.Mesh.Nodes;

% Boundary conditions: simply-supported along all four edges
% Curved edges (z=0, z=L): pin Uy and Uz (diaphragm)
z0_nodes = Pre.selectNodesOnPlane(3, 0.0, 1e-4);
zL_nodes = Pre.selectNodesOnPlane(3, L,   1e-4);
Pre.addBC(z0_nodes, [2, 3], 0, 'SupportZ0');
Pre.addBC(zL_nodes, [2, 3], 0, 'SupportZL');

% Straight longitudinal edges at y = R*sin(-ang) and y = R*sin(+ang).
% createCylinderPanel maps angle -> (x=R*cos, y=R*sin), so straight
% edges (constant angle) lie at constant y, not constant x.
yA_nodes = Pre.selectNodesOnPlane(2, R*sin(-ang), 1e-3);
yB_nodes = Pre.selectNodesOnPlane(2, R*sin( ang), 1e-3);
if ~isempty(yA_nodes), Pre.addBC(yA_nodes, 1, 0, 'SupportY'); end
if ~isempty(yB_nodes), Pre.addBC(yB_nodes, 1, 0, 'SupportY'); end

% Unit reference load at crown (apex: x≈0, y=R, z=L/2)
crown_node = find_crown_node(nodes, R, L);
Pre.addNodalLoad(crown_node, 3, -1.0, 'CrownLoad');  % unit load, scaled by lambda

% Apply geometric imperfection via first buckling mode
% Step 1: solve static under reference load
Sol_lin = FEM_Solver(Pre);
Sol_lin.solveStaticDisplacement();
Sol_lin.applyConstraints();
Sol_lin.solveBuckling(1);

if ~isempty(Sol_lin.ModeShapes)
    amplitude = t / 100;
    Pre.applyImperfection(Sol_lin.ModeShapes(:, 1), amplitude);
    fprintf('  [Crisfield] Applied geometric imperfection: amplitude = %g m (t/100)\n', amplitude);
else
    warning('verify_cylindrical_panel_riks:noBuckling', ...
            'Buckling modes not available; proceeding without imperfection');
end

% ----------------------------------------------------------------
% VT4.2  Run Riks arc-length analysis
% ----------------------------------------------------------------
opts = SolverOptions();
opts.MaxIterations = 20;
opts.TolForce      = 1e-4;
opts.NormType      = 'force';

Sol = FEM_Solver_Nonlinear(Pre, opts);

S1 = LoadingStage(2.0);   % duration allows lambda > P_ref if needed
S1.strategy = RiksStrategy( ...
    'ArcLengthRadius', 0.02, ...
    'ArcLengthMin',    1e-5, ...
    'ArcLengthMax',    0.3,  ...
    'Psi',             1.0);
S1.activateBC('SupportZ0');
S1.activateBC('SupportZL');
S1.activateBC('SupportY');
S1.activateLoad('CrownLoad');

Sol.solve({S1});

lh = Sol.LambdaHist;   % load factors (lambda * 1 N = force in N)
nSteps = Sol.StepCount;

fprintf('  [Crisfield] Completed %d Riks steps\n', nSteps);
fprintf('  [Crisfield] Lambda range: [%g, %g]\n', min(lh), max(lh));

% ----------------------------------------------------------------
% VT4.4  Peak load check (P_peak = max(lambda * 1N))
% ----------------------------------------------------------------
P_peak = max(lh);
rel_err = abs(P_peak - P_ref) / P_ref;
fprintf('  [Crisfield] P_peak = %g N,  P_ref = %g N,  error = %.2f%%\n', ...
    P_peak, P_ref, rel_err * 100);

if rel_err > 0.05
    error(['CRISFIELD FAILED: P_peak = %g N vs P_ref = %g N, ' ...
           'error = %.2f%% > 5%%.'], P_peak, P_ref, rel_err * 100);
end

% ----------------------------------------------------------------
% VT4.5  Snap-through: min(diff(LambdaHist)) < 0
% ----------------------------------------------------------------
if min(diff(lh)) >= 0
    error(['CRISFIELD FAILED: snap-through not detected. ' ...
           'LambdaHist is monotonically non-decreasing.']);
end
fprintf('  [Crisfield] Snap-through detected: min(diff(lambda)) = %g\n', ...
    min(diff(lh)));
end

% ----------------------------------------------------------------
function cn = find_crown_node(nodes, R, L)
% Crown is at (0, R, L/2).
dists = sqrt(nodes(:,1).^2 + (nodes(:,2)-R).^2 + (nodes(:,3)-L/2).^2);
[~, cn] = min(dists);
end
