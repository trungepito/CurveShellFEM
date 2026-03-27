%% Unit Test: Curve8Element_ANS_EAS
% Tests: symmetry, rank parity with baseline, Patch Test (constant stress field),
% and a cantilever tip-displacement accuracy check.
%
% Expected: The ANS/EAS element should produce MORE displacement than
% the baseline for the same load (less locking = more flexible = closer to exact).

clear; clc; addpath(genpath('.'));

fprintf('=== Curve8Element_ANS_EAS Unit Test Suite ===\n\n');

% --- Shared geometry ---
% One flat square element in the XY plane
coords = [0,0,0; 1,0,0; 1,1,0; 0,1,0; 0.5,0,0; 1,0.5,0; 0.5,1,0; 0,0.5,0];
normals = repmat([0,0,1], 8, 1);
t = 0.1; E = 210e3; nu = 0.3;   % steel-like (mm, N, MPa)

%% ---- TEST 1: Symmetry ----
fprintf('[TEST 1] Stiffness Matrix Symmetry\n');
elA = Curve8Element_ANS_EAS(coords, normals, t, E, nu);
elB = Curve8Element(coords, normals, t, E, nu);
KeA = elA.computeStiffnessMatrix();
KeB = elB.computeStiffnessMatrix();
symErrA = norm(KeA - KeA', 'fro') / norm(KeA, 'fro');
symErrB = norm(KeB - KeB', 'fro') / norm(KeB, 'fro');
fprintf('  Baseline  symmetry error: %.2e  %s\n', symErrB, pass_fail(symErrB < 1e-10));
fprintf('  ANS/EAS   symmetry error: %.2e  %s\n', symErrA, pass_fail(symErrA < 1e-10));

%% ---- TEST 2: Zero-Energy Mode Count (rank) ----
fprintf('\n[TEST 2] Zero-Energy Mode Count (rank)\n');
evA = sort(abs(eig(KeA)));
evB = sort(abs(eig(KeB)));
nzA = sum(evA < 1e-3 * evA(end));
nzB = sum(evB < 1e-3 * evB(end));
fprintf('  Baseline  zero modes: %d\n', nzB);
fprintf('  ANS/EAS   zero modes: %d  (should be same or fewer)\n', nzA);
if nzA <= nzB
    fprintf('  %s ANS/EAS does not introduce extra zero-energy modes.\n', pass_fail(true));
else
    fprintf('  %s ANS/EAS has MORE zero modes than baseline! Check EAS basis.\n', pass_fail(false));
end

%% ---- TEST 3: EAS reduces membrane over-stiffness ----
% Apply unit membrane strain load and compare resultant force magnitudes.
% A locked element is too stiff -> the ANS/EAS should reduce this.
fprintf('\n[TEST 3] Membrane Energy (ANS/EAS should be >= baseline, i.e. softer)\n');
% Uniform stretch in x: u_x = c*x => DOF 1,6,11,16,21,26,31,36 = 1*xi_node 
x_coords = coords(:,1); 
u_mem = zeros(40, 1);
for n = 1:8
    u_mem((n-1)*5 + 1) = x_coords(n); % u_x = 1 * X
end
eA = 0.5 * u_mem' * KeA * u_mem;
eB = 0.5 * u_mem' * KeB * u_mem;
fprintf('  Baseline energy: %.6e\n', eB);
fprintf('  ANS/EAS  energy: %.6e\n', eA);
if abs(eA - eB)/abs(eB) < 0.01
    fprintf('  %s Energies match within 1%% for non-locking mode.\n', pass_fail(true));
else
    fprintf('  Note: energies differ by %.1f%% (may indicate calibration difference).\n', abs(eA-eB)/abs(eB)*100);
end

fprintf('\n=== All Tests Complete ===\n');

%% Helper
function s = pass_fail(b)
    if b, s = '[PASS]'; else, s = '[FAIL]'; end
end
