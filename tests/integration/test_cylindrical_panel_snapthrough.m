function result = test_cylindrical_panel_snapthrough()
% TEST_CYLINDRICAL_PANEL_SNAPTHROUGH  Integration tests for arc-length snap-through.
%
% Covers IT4.1-IT4.4:
%   IT4.1  RiksStrategy 20-step solve: StepCount == 20
%   IT4.2  LambdaHist is NOT monotonically increasing (snap-through detected)
%   IT4.3  Crown displacement increases monotonically despite load reversal
%   IT4.4  All steps converged (no step used > MaxIterations iterations)
%
% Geometry: hinged cylindrical panel, R=2540mm, L=508mm, theta=0.1rad, t=5mm
% This is the Riks (1979) benchmark geometry at reduced scale for speed.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_cylindrical_panel_snapthrough');

% ----------------------------------------------------------------
% Geometry and material
% ----------------------------------------------------------------
R    = 2540e-3;      % m
L    = 508e-3;       % m
t    = 5e-3;         % m
ang  = 0.1;          % half-angle in radians
E    = 3.1027e10;    % Pa (equivalent to 3102.75 kgf/cm2 in SI)
nu   = 0.3;

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createCylinderPanel(R, L, -ang, ang);
Pre.meshAllPatches(4, 4);   % 4x4 mesh per quadrant — coarse for speed

nNodes = size(Pre.Mesh.Nodes, 1);

% Boundary conditions: all edges simply supported (Uz=0, rotations free)
% Curved edges (longitudinal): pin Uz
% Straight edges (circumferential): pin Uz + Ux (to prevent rigid body)
edge_z0 = Pre.selectNodesOnPlane(3, 0.0,  1e-3);
edge_zL = Pre.selectNodesOnPlane(3, L,    1e-3);

Pre.addBC(edge_z0, 3, 0, 'SupportZ0');
Pre.addBC(edge_z0, 4, 0, 'SupportZ0');
Pre.addBC(edge_zL, 3, 0, 'SupportZL');
Pre.addBC(edge_zL, 4, 0, 'SupportZL');

% Symmetry BCs at x=0 plane (panel centre)
sym_x = Pre.selectNodesOnPlane(1, 0.0, 1e-3);
Pre.addBC(sym_x, 1, 0, 'SymX');
Pre.addBC(sym_x, 5, 0, 'SymX');

% Pin corners for in-plane stability
corners = Pre.selectNodesByBox(-1e-3, 1e-3, -1e-3, 1e-3, -1e-3, 1e-3);
if ~isempty(corners)
    Pre.addBC(corners, [1,2], 0, 'Pin');
end

% Point load at crown (apex node: x=0, y=R, z=L/2)
crown_nodes = Pre.selectNodesByBox( ...
    -1e-3, 1e-3, R-1e-3, R+1e-3, L/2-1e-3, L/2+1e-3);
if isempty(crown_nodes)
    % Fallback: find node closest to crown
    nodes = Pre.Mesh.Nodes;
    [~, crown_nodes] = min( ...
        abs(nodes(:,1)) + abs(nodes(:,2)-R) + abs(nodes(:,3)-L/2));
end
crown_node = crown_nodes(1);

P_ref = 1000;   % Reference load magnitude (N)
Pre.addNodalLoad(crown_node, 3, -P_ref, 'CrownLoad');   % downward

% Solver setup
opts = SolverOptions();
opts.MaxIterations = 25;
opts.TolForce      = 1e-4;
opts.NormType      = 'force';

Sol = FEM_Solver_Nonlinear(Pre, opts);

S1 = LoadingStage(1.0);
S1.strategy = RiksStrategy( ...
    'ArcLengthRadius', 0.05, ...
    'ArcLengthMin',    1e-4, ...
    'ArcLengthMax',    0.5,  ...
    'Psi',             1.0);
S1.activateBC('SupportZ0');
S1.activateBC('SupportZL');
S1.activateBC('SymX');
S1.activateBC('Pin');
S1.activateLoad('CrownLoad');

Sol.solve({S1});

nSteps = Sol.StepCount;

% ----------------------------------------------------------------
% IT4.1 -- StepCount approximately 20 (Riks can overshoot by 1)
% ----------------------------------------------------------------
result = run_subtest(result, 'IT4.1 StepCount == 20', @() ...
    assert_equal(nSteps, 20, 2, 'StepCount'));

% ----------------------------------------------------------------
% IT4.2 -- LambdaHist shows load reversal (snap-through detected)
% ----------------------------------------------------------------
result = run_subtest(result, 'IT4.2 LambdaHist shows load reversal', ...
    @() it4_2(Sol, nSteps));

% ----------------------------------------------------------------
% IT4.3 — Crown displacement monotonically increases
% ----------------------------------------------------------------
result = run_subtest(result, 'IT4.3 Crown displacement monotone increasing', ...
    @() it4_3(Sol, crown_node, nSteps));

% ----------------------------------------------------------------
% IT4.4 — All steps converged (ArcLengthHist all > 0)
% ----------------------------------------------------------------
result = run_subtest(result, 'IT4.4 all steps converged', @() it4_4(Sol, nSteps));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function it4_2(Sol, nSteps)
% Snap-through reversal may only appear in the second half of steps
% after the limit point is passed.  Check the later portion.
lh = Sol.LambdaHist(1:nSteps);
half = max(1, floor(nSteps/2));
lh_late = lh(half:end);
if all(diff(lh_late) >= 0)
    error(['No load reversal in steps %d-%d of LambdaHist. ' ...
           'Snap-through not detected (min(diff)=%g). ' ...
           'Check panel geometry, BCs, or increase steps.'], ...
           half, nSteps, min(diff(lh_late)));
end
end

% ----------------------------------------------------------------
function it4_3(Sol, crown_node, nSteps)
% DOF for Uz at crown node
uz_dof = (crown_node - 1) * 6 + 3;

uz = zeros(nSteps, 1);
for s = 1:nSteps
    U = Sol.state.getU(s);
    uz(s) = U(uz_dof);
end

% Crown moves in negative Z direction; |uz| should increase
mag_uz = abs(uz);
for s = 2:nSteps
    if mag_uz(s) < mag_uz(s-1) - 1e-8
        error('Crown displacement not monotone: |uz(%d)| = %g < |uz(%d)| = %g', ...
              s, mag_uz(s), s-1, mag_uz(s-1));
    end
end
end

% ----------------------------------------------------------------
function it4_4(Sol, nSteps)
% ArcLengthHist stores the arc-length radius used per step.
% All values > 0 means each step converged (0 would indicate failure).
alh = Sol.state.ArcLengthHist(1:nSteps);
if any(alh <= 0)
    n_fail = sum(alh <= 0);
    error('%d step(s) have ArcLengthHist <= 0 (convergence failure)', n_fail);
end
end
