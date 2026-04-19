function result = verify_beam_bending()
% VERIFY_BEAM_BENDING  Cantilever beam tip deflection vs Euler-Bernoulli theory.
%
% VT2.1  Build cantilever: E=210 GPa, nu=0.3, t=0.01m, L=1m, w=0.1m, F=1N.
% VT2.2  Run linear static with 4 elements along length.
% VT2.3  Analytical: delta = F*L^3 / (3*E*I), I = w*t^3/12.
% VT2.4  PASS: |delta_tip - delta_ref| / delta_ref < 0.02 (2% tolerance).
%
% Shell elements model bending through the Reissner-Mindlin formulation;
% the Kirchhoff limit (thin plate) should be approached for t/L << 1.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('verify_beam_bending');

result = run_subtest(result, 'VT2.1-VT2.4 tip deflection within 2%', ...
    @() run_beam_bending());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_beam_bending()
% Material and geometry
E   = 210e9;     % Pa
nu  = 0.3;
t   = 0.01;      % m (thickness — the bending plane direction)
L   = 1.0;       % m (length along x)
w   = 0.1;       % m (width along y — this is the strong-axis)
F   = 1.0;       % N (tip transverse load in z)

% Second moment of area for bending about y-axis (load in z, width w, thickness t):
% Beam cross-section: w (in y) x t (in z).
% I = w * t^3 / 12  (bending about y-axis, load in z)
I       = w * t^3 / 12;
delta_ref = F * L^3 / (3 * E * I);   % Euler-Bernoulli tip deflection

fprintf('  [Beam Bending] Analytical tip deflection = %.6e m\n', delta_ref);

% ----------------------------------------------------------------
% VT2.2  Build model: plate L x w in XY plane, bending in Z
% ----------------------------------------------------------------
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createPlate([0, 0, 0], L, w);
Pre.meshAllPatches(4, 1);   % 4 elements along x, 1 along y

nNodes = size(Pre.Mesh.Nodes, 1);

% Clamped root: all DOFs fixed at x=0
root_nodes = Pre.selectNodesOnPlane(1, 0.0, 1e-4);
Pre.addBC(root_nodes, 1:6, 0, 'Clamp');

% Tip load in Z direction applied to all nodes at x=L
tip_nodes  = Pre.selectNodesOnPlane(1, L, 1e-4);
F_per_node = F / length(tip_nodes);
Pre.addNodalLoad(tip_nodes, 3, F_per_node, 'TipLoad');

Sol = FEM_Solver(Pre);
Sol.solveStaticDisplacement();

% ----------------------------------------------------------------
% VT2.2  Tip deflection: average Uz at x=L
% ----------------------------------------------------------------
tip_uz_dofs = (tip_nodes - 1) * 6 + 3;
delta_FEM   = mean(abs(Sol.U(tip_uz_dofs)));

rel_err = abs(delta_FEM - delta_ref) / delta_ref;
fprintf('  [Beam Bending] FEM tip deflection = %.6e m\n', delta_FEM);
fprintf('  [Beam Bending] Relative error     = %.2f%%  (tol 2%%)\n', rel_err * 100);

if rel_err > 0.02
    error(['BEAM BENDING FAILED: delta_FEM = %g m, delta_ref = %g m, ' ...
           'rel error = %.2f%% > 2%%.\nCheck Mindlin shear locking (use ANS_EAS ' ...
           'element or reduced shear integration).'], ...
          delta_FEM, delta_ref, rel_err * 100);
end
end
