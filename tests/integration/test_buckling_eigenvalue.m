function result = test_buckling_eigenvalue()
% TEST_BUCKLING_EIGENVALUE  Integration tests for linear buckling analysis.
%
% Covers IT5.1-IT5.3:
%   IT5.1  First buckling factor within 5% of analytical Ncr
%   IT5.2  ModeShapes has 3 columns of length nDofs
%   IT5.3  Mode shapes are max-normalised (source must do this)

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_buckling_eigenvalue');

% ----------------------------------------------------------------
% Simply-supported square plate under uniform in-plane compression.
% Analytical: Ncr = pi^2 * D / a^2  (m=n=1 mode)
%   D = E*t^3 / (12*(1-nu^2))
%
% BCs that correctly generate in-plane compression:
%   - Uz = 0, Rx = 0, Ry = 0  on all four edges (SS bending BCs)
%   - Ux = 0  on x=0 edge ONLY (reaction; allows free expansion on others)
%   - Uy = 0  at one node on x=0 edge (suppress in-plane RBM)
%   - Nodal load Fx < 0 on x=a edge (compressive reference force)
% ----------------------------------------------------------------
E  = 200e9;
nu = 0.3;
t  = 0.010;
a  = 1.0;

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createPlate([0, 0, 0], a, a);
Pre.meshAllPatches(4, 4);

nNodes = size(Pre.Mesh.Nodes, 1);
nDofs  = nNodes * 6;

% SS bending BCs on all four edges
for dim = 1:2
    for val = [0, a]
        edge = Pre.selectNodesOnPlane(dim, val, 1e-4);
        Pre.addBC(edge, 3, 0, 'SS_uz');
        Pre.addBC(edge, 4, 0, 'SS_rx');
        Pre.addBC(edge, 5, 0, 'SS_ry');
    end
end

% In-plane BCs: fix Ux on x=0 only; single-node Uy fix
x0_edge = Pre.selectNodesOnPlane(1, 0.0, 1e-4);
Pre.addBC(x0_edge,    1, 0, 'Reaction');
Pre.addBC(x0_edge(1), 2, 0, 'RBM');

% Reference load: total force = Nx * a distributed over x=a nodes.
% Ncr_FEM = lambda_1 * |total_force| / a  = lambda_1 * Nx.
Nx       = 1.0;    % N/m reference
xL_nodes = Pre.selectNodesOnPlane(1, a, 1e-4);
F_each   = -Nx * a / length(xL_nodes);
Pre.addNodalLoad(xL_nodes, 1, F_each, 'Compress');

Sol = FEM_Solver(Pre);
Sol.solveStaticDisplacement();
Sol.applyConstraints();
Sol.solveBuckling(3);

% ----------------------------------------------------------------
% IT5.1 -- First buckling factor within 5% of analytical
% ----------------------------------------------------------------
result = run_subtest(result, 'IT5.1 lambda_1 within 5% of Ncr_analytical', ...
    @() it5_1(Sol, E, nu, t, a, Nx));

% ----------------------------------------------------------------
% IT5.2 -- ModeShapes size
% ----------------------------------------------------------------
result = run_subtest(result, 'IT5.2 ModeShapes size [nDofs x 3]', ...
    @() it5_2(Sol, nDofs));

% ----------------------------------------------------------------
% IT5.3 -- Mode shapes are max-normalised
% ----------------------------------------------------------------
result = run_subtest(result, 'IT5.3 mode shapes max-normalised', ...
    @() it5_3(Sol));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function it5_1(Sol, E, nu, t, a, Nx)
D   = E * t^3 / (12 * (1 - nu^2));
Ncr = pi^2 * D / a^2;   % N/m analytical

% lambda_1 * |total_force| / a = lambda_1 * Nx  (N/m)
Ncr_FEM = Sol.BucklingFactors(1) * Nx;

rel_err = abs(Ncr_FEM - Ncr) / Ncr;
fprintf('  [IT5.1] lambda_1=%g, Ncr_FEM=%.4g N/m, Ncr_ref=%.4g N/m, err=%.2f%%\n', ...
    Sol.BucklingFactors(1), Ncr_FEM, Ncr, rel_err*100);

if rel_err > 0.05
    error('lambda_1=%g -> Ncr_FEM=%g N/m, analytical=%g N/m, error=%.2f%% > 5%%', ...
          Sol.BucklingFactors(1), Ncr_FEM, Ncr, rel_err*100);
end
end

% ----------------------------------------------------------------
function it5_2(Sol, nDofs)
[r, c] = size(Sol.ModeShapes);
if r ~= nDofs
    error('ModeShapes has %d rows, expected nDofs=%d', r, nDofs);
end
if c < 3
    error('ModeShapes has %d columns, expected >= 3', c);
end
end

% ----------------------------------------------------------------
function it5_3(Sol)
% solveBuckling must max-normalise each eigenvector before storing.
% Source fix required in src/@FEM_Solver/solveBuckling.m if this fails.
for k = 1:min(3, size(Sol.ModeShapes, 2))
    phi  = Sol.ModeShapes(:, k);
    mval = max(abs(phi));
    if abs(mval - 1.0) > 1e-10
        error(['Mode %d: max(|phi|)=%g, expected 1.0 (not max-normalised).\n' ...
               'Add max-normalisation to src/@FEM_Solver/solveBuckling.m:\n' ...
               '  for k=1:size(V,2); V(:,k)=V(:,k)/max(abs(V(:,k))); end'], ...
               k, mval);
    end
end
end
