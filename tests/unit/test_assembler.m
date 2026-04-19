function result = test_assembler()
% TEST_ASSEMBLER  Unit tests for the stateless Assembler class.
%
% Covers UT1.1–UT1.5 from the implementation plan.
%   UT1.1  Elastic stiffness matrix is symmetric
%   UT1.2  Rank after BCs equals number of free DOFs
%   UT1.3  Internal force at zero displacement is zero
%   UT1.4  Tangent at zero displacement matches elastic stiffness
%   UT1.5  Assembly time for 100 elements is < 5 seconds

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_assembler');

% ----------------------------------------------------------------
% Build a minimal 4-element flat plate model
% ----------------------------------------------------------------
E  = 2.1e11;
nu = 0.3;
t  = 0.01;
Pre = make_plate_model('E', E, 'nu', nu, 't', t, 'L', 1.0, 'Ne', 2, 'bc', 'clamped');
Sol = FEM_Solver(Pre);
Sol.assembleK();

nDofs   = size(Pre.Mesh.Nodes, 1) * 6;
nElems  = size(Pre.Mesh.Elements, 1);

% ----------------------------------------------------------------
% UT1.1 — Symmetry of elastic stiffness matrix
% ----------------------------------------------------------------
result = run_subtest(result, 'UT1.1 K is symmetric', @() ...
    assert_equal( ...
        norm(Sol.GlobalK - Sol.GlobalK', 'fro'), ...
        0, 1e-8 * norm(Sol.GlobalK, 'fro'), ...
        'Symmetry violation'));

% ----------------------------------------------------------------
% UT1.2 — Rank of K before and after BCs
% ----------------------------------------------------------------
result = run_subtest(result, 'UT1.2 rank(K_ff) == length(free_dofs)', @() ut1_2(Sol, nDofs));

% ----------------------------------------------------------------
% UT1.3 — Internal force at zero displacement is zero
% ----------------------------------------------------------------
result = run_subtest(result, 'UT1.3 F_int(0) == 0', @() ut1_3(Sol, nDofs));

% ----------------------------------------------------------------
% UT1.4 — Tangent at zero displacement matches elastic stiffness
% ----------------------------------------------------------------
result = run_subtest(result, 'UT1.4 KT(0) == K_elastic', @() ut1_4(Sol, nDofs));

% ----------------------------------------------------------------
% UT1.5 — Assembly time for 100-element mesh < 5 s
% ----------------------------------------------------------------
result = run_subtest(result, 'UT1.5 assembly < 5 s for 100 elements', @() ut1_5(E, nu, t));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function ut1_2(Sol, nDofs)
% Rank of K_ff must equal length(free_dofs).
% For a clamped plate every edge DOF is fixed; the reduced system
% must be full rank.
Sol.applyConstraints();
free = Sol.FreeDofs;
K_ff = Sol.GlobalK(free, free);
r = rank(full(K_ff));
expected = length(free);
if r ~= expected
    error('rank(K_ff)=%d, expected %d', r, expected);
end
end

% ----------------------------------------------------------------
function ut1_3(Sol, nDofs)
% Assembler.internalForce at U=0 must return exactly zero.
U_zero = zeros(nDofs, 1);
F_int = Assembler.internalForce(U_zero, Sol.Elements, Sol.SctrMap, nDofs);
nrm = norm(F_int);
if nrm > 1e-12
    error('||F_int(0)|| = %g, expected 0', nrm);
end
end

% ----------------------------------------------------------------
function ut1_4(Sol, nDofs)
% KT at zero displacement must match the elastic stiffness K.
% Both are assembled from the same element objects; the geometric
% nonlinearity contribution is zero at U=0.
U_zero = zeros(nDofs, 1);
[KT, ~, ~] = Assembler.tangent(U_zero, Sol.Elements, Sol.SctrMap, nDofs);
K_el = Sol.GlobalK;

rel_err = norm(KT - K_el, 'fro') / max(norm(K_el, 'fro'), 1e-30);
if rel_err > 1e-10
    error('||KT - K_el|| / ||K_el|| = %g, expected < 1e-10', rel_err);
end
end

% ----------------------------------------------------------------
function ut1_5(E, nu, t)
% Build a 10x10 mesh (~100 elements) and time the assembly.
Pre100 = make_plate_model('E', E, 'nu', nu, 't', t, 'L', 1.0, 'Nu', 10, 'bc', 'clamped');
Sol100 = FEM_Solver(Pre100);
nDofs  = size(Pre100.Mesh.Nodes, 1) * 6;

t0 = tic;
Assembler.elastic(Sol100.Elements, Sol100.SctrMap, nDofs);
elapsed = toc(t0);

if elapsed > 5.0
    error('Assembly of 100 elements took %.2f s (limit 5 s)', elapsed);
end
end
