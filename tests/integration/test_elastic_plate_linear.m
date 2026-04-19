function result = test_elastic_plate_linear()
% TEST_ELASTIC_PLATE_LINEAR  Integration tests for linear static plate analysis.
%
% Covers IT1.1–IT1.4:
%   IT1.1  Max deflection within 5% of thin-plate analytical solution
%   IT1.2  BucklingFactors empty before solveBuckling
%   IT1.3  solveBuckling(3) returns 3 positive eigenvalues
%   IT1.4  FEM_Postprocessor_v2 returns von_mises field of correct length

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_elastic_plate_linear');

% ----------------------------------------------------------------
% Model: 1m x 1m clamped plate, 4x4 mesh, uniform pressure q = 1 kPa
% Material: E = 200 GPa, nu = 0.3, t = 0.02 m
% ----------------------------------------------------------------
E  = 200e9;
nu = 0.3;
t  = 0.02;
L  = 1.0;
q  = 1e3;   % Pa (uniform pressure)

Pre = make_plate_model('E', E, 'nu', nu, 't', t, 'L', L, 'Ne',10, 'bc', 'clamped');

% Apply uniform pressure on all elements
all_elems = (1 : size(Pre.Mesh.Elements, 1))';
Pre.addPressureLoad(all_elems, q, 'Pressure');

Sol = FEM_Solver(Pre);
Sol.solveStaticDisplacement();

nNodes = size(Pre.Mesh.Nodes, 1);
nDofs  = nNodes * 6;

% ----------------------------------------------------------------
% IT1.1 — Max deflection vs analytical thin-plate solution
% ----------------------------------------------------------------
result = run_subtest(result, 'IT1.1 max deflection within 5% of analytical', ...
    @() it1_1(Sol, E, nu, t, L, q, nNodes));

% ----------------------------------------------------------------
% IT1.2 — BucklingFactors empty before solveBuckling
% ----------------------------------------------------------------
result = run_subtest(result, 'IT1.2 BucklingFactors empty before buckling solve', ...
    @() it1_2(Sol));

% ----------------------------------------------------------------
% IT1.3 — solveBuckling(3) returns 3 positive eigenvalues
% ----------------------------------------------------------------
result = run_subtest(result, 'IT1.3 solveBuckling(3) returns 3 positive factors', ...
    @() it1_3(E,nu,t,L));

% ----------------------------------------------------------------
% IT1.4 — Postprocessor returns von_mises of correct size
% ----------------------------------------------------------------
result = run_subtest(result, 'IT1.4 postprocessor von_mises field size', ...
    @() it1_4(Pre, Sol, nNodes));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function it1_1(Sol, E, nu, t, L, q, nNodes)
% Analytical max deflection for a uniformly loaded clamped square plate.
% Timoshenko formula: w_max = 0.00126 * q * a^4 / (D)
% where D = E*t^3 / (12*(1-nu^2)).
D      = E * t^3 / (12 * (1 - nu^2));
w_ref  = 0.00126 * q * L^4 /D;

% Extract Uz (DOF 3) for all nodes
U_z    = Sol.U(3:6:end);
w_max  = max(abs(U_z));

rel_err = abs(w_max - w_ref) / w_ref;
if rel_err > 0.05
    error('Max deflection = %g m, analytical = %g m, rel error = %.2f%% > 5%%', ...
          w_max, w_ref, rel_err * 100);
end
end

% ----------------------------------------------------------------
function it1_2(Sol)
if ~isempty(Sol.BucklingFactors)
    error('BucklingFactors should be empty before solveBuckling, got %d entries', ...
          length(Sol.BucklingFactors));
end
end

% ----------------------------------------------------------------
function it1_3(E, nu, t, a)
% Separate SS plate model with uniform in-plane compression.
% A transverse-pressure model has Kg near zero (no membrane forces)
% so buckling cannot be solved from it. This model generates real Kg.
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createPlate([0, 0, 0], a, a);
Pre.meshAllPatches(4, 4);

% Simply-supported: fix Uz and rotations on all edges
for dim = 1:2
    for val = [0, a]
        edge = Pre.selectNodesOnPlane(dim, val, 1e-4);
        Pre.addBC(edge, 3, 0, 'SS_uz');
        Pre.addBC(edge, 4, 0, 'SS_rx');
        Pre.addBC(edge, 5, 0, 'SS_ry');
    end
end
% Fix Ux on x=0 (reaction edge); one node fixes Uy for RBM
x0_edge = Pre.selectNodesOnPlane(1, 0.0, 1e-4);
Pre.addBC(x0_edge,    1, 0, 'Reaction');
Pre.addBC(x0_edge(1), 2, 0, 'RBM');

% Reference in-plane compression: Nx=1 N/m on x=a edge
Nx       = 1.0;
xL_nodes = Pre.selectNodesOnPlane(1, a, 1e-4);
F_each   = -Nx * a / length(xL_nodes);
Pre.addNodalLoad(xL_nodes, 1, F_each, 'Compress');

Sol = FEM_Solver(Pre);
Sol.solveStaticDisplacement();
Sol.applyConstraints();

Sol.solveBuckling(3);

n = length(Sol.BucklingFactors);
if n < 3
    error('solveBuckling(3) returned %d factor(s), expected 3', n);
end
neg = Sol.BucklingFactors(Sol.BucklingFactors <= 0);
if ~isempty(neg)
    error('%d negative/zero buckling factor(s), min=%g', length(neg), min(neg));
end
fprintf('  [IT1.3] lambda = [%.3g, %.3g, %.3g]\n', ...
    Sol.BucklingFactors(1), Sol.BucklingFactors(2), Sol.BucklingFactors(3));
end

% ----------------------------------------------------------------
function it1_4(Pre, Sol, nNodes)
Post  = FEM_Postprocessor_v2(Pre, Sol);
field = Post.recoverField('von_mises', 1);

if length(field) ~= nNodes
    error('von_mises field has %d entries, expected %d (nNodes)', ...
          length(field), nNodes);
end

% All values must be finite and non-negative
if any(~isfinite(field))
    error('von_mises contains non-finite values');
end
if any(field < -1e-6)
    error('von_mises contains negative values (min = %g)', min(field));
end
end
