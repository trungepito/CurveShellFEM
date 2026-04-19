function result = test_incremental_strategies()
% TEST_INCREMENTAL_STRATEGIES  Unit tests for all IncrementalStrategy subclasses.
%
% Covers UT6.1–UT6.5 from the implementation plan.
%   UT6.1  RiksStrategy predictor solves the tangent system
%   UT6.2  RiksStrategy constraint is zero at predictor point
%   UT6.3  LoadControlStrategy constraint is lambda - (l0 + ds)
%   UT6.4  DispControlStrategy constraint after initialize()
%   UT6.5  adaptRadius increases/decreases radius correctly

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_incremental_strategies');

% Shared tiny system: 4 free DOFs
nFree = 4;
nDofs = 6;                     % 4 free + 2 fixed
free_dofs = [1 2 3 4];

rng(99);
% SPD tangent stiffness for the free partition
A = rand(nFree);
KT_ff = A' * A + 2 * eye(nFree);   % guaranteed SPD

F_ext_f = ones(nFree, 1);
u0 = zeros(nDofs, 1);
l0 = 0.5;
ds = 0.05;

% ----------------------------------------------------------------
% UT6.1 — RiksStrategy predictor solves KT_ff * dup_f = F_ext_f
% ----------------------------------------------------------------
result = run_subtest(result, 'UT6.1 Riks predictor tangent solve', ...
    @() ut6_1(KT_ff, F_ext_f, u0, l0, ds, free_dofs, nDofs));

% ----------------------------------------------------------------
% UT6.2 — RiksStrategy constraint g == 0 at predictor point (u1, l1)
% ----------------------------------------------------------------
result = run_subtest(result, 'UT6.2 Riks constraint zero at predictor', ...
    @() ut6_2(KT_ff, F_ext_f, u0, l0, ds, free_dofs, nDofs));

% ----------------------------------------------------------------
% UT6.3 — LoadControlStrategy constraint g = lambda - (l0 + ds)
% ----------------------------------------------------------------
result = run_subtest(result, 'UT6.3 LoadControl constraint formula', @() ut6_3(l0, ds));

% ----------------------------------------------------------------
% UT6.4 — DispControlStrategy: initialize then constraint check
% ----------------------------------------------------------------
result = run_subtest(result, 'UT6.4 DispControl constraint after initialize', ...
    @() ut6_4(KT_ff, F_ext_f, u0, l0, ds, free_dofs, nDofs));

% ----------------------------------------------------------------
% UT6.5 — adaptRadius logic
% ----------------------------------------------------------------
result = run_subtest(result, 'UT6.5 adaptRadius grows and shrinks correctly', @() ut6_5());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function ut6_1(KT_ff, F_ext_f, u0, l0, ds, free_dofs, nDofs)
% Predictor dup_f must satisfy KT_ff * dup_f = F_ext_f (up to scaling).
strat = RiksStrategy('ArcLengthRadius', ds);
dup_prev = zeros(nDofs, 1);

[~, ~, dup, ~] = strat.predictor(KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs);

dup_f       = dup(free_dofs);
expected_f  = KT_ff \ F_ext_f;

% dup_f must be proportional to expected_f (differ only by dlp scaling)
% Normalize both and check alignment.
n_dup = dup_f / max(norm(dup_f), 1e-30);
n_exp = expected_f / max(norm(expected_f), 1e-30);
err   = norm(n_dup - n_exp);

if err > 1e-10
    error('Predictor direction error = %g (not aligned with KT_ff \\ F_ext_f)', err);
end
end

% ----------------------------------------------------------------
function ut6_2(KT_ff, F_ext_f, u0, l0, ds, free_dofs, nDofs)
% At the predictor point (u1, l1) the Riks constraint must be exactly zero.
strat = RiksStrategy('ArcLengthRadius', ds, 'Psi', 1.0);
dup_prev = zeros(nDofs, 1);

[u1, l1, dup, dlp] = strat.predictor(KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs);

[g, ~, ~] = strat.constraint(u1(free_dofs), l1, u0(free_dofs), l0, dup(free_dofs), dlp, ds);

if abs(g) > 1e-10
    error('Riks constraint at predictor point = %g, expected 0', g);
end
end

% ----------------------------------------------------------------
function ut6_3(l0, ds)
% LoadControl constraint: g = lambda - (l0 + ds).
strat = LoadControlStrategy('ArcLengthRadius', ds);

lambda_test = l0 + ds + 0.03;   % slightly off target
[g, ~, s] = strat.constraint([], lambda_test, [], l0, [], [], ds);

expected_g = lambda_test - (l0 + ds);
if abs(g - expected_g) > 1e-14
    error('g = %g, expected %g', g, expected_g);
end

if s ~= 1
    error('s must be 1 for LoadControl, got %g', s);
end
end

% ----------------------------------------------------------------
function ut6_4(KT_ff, F_ext_f, u0, l0, ds, free_dofs, nDofs)
% DispControlStrategy: initialize, then constraint check.

% Global DOF 2 is free (free_dofs = [1,2,3,4])
ctrl_dof = 2;
strat = DispControlStrategy(ctrl_dof, 'ArcLengthRadius', ds);

% 1. Constraint before initialize must throw
errFired = false;
try
    u_dummy = rand(length(free_dofs), 1);
    strat.constraint(u_dummy, 0, zeros(length(free_dofs),1), 0, [], [], ds);
catch ME
    if contains(ME.identifier, 'notInitialized') || contains(ME.message, 'initialize')
        errFired = true;
    else
        rethrow(ME);
    end
end
if ~errFired
    error('constraint() before initialize() must throw notInitialized error');
end

% 2. After initialize, constraint must work correctly
strat.initialize(free_dofs);

if strat.ControlDOF_local < 1
    error('ControlDOF_local = %d after initialize, expected >= 1', strat.ControlDOF_local);
end

% Build trial state: impose displacement at ctrl_dof
u0_f  = zeros(length(free_dofs), 1);
u_f   = u0_f;
local = strat.ControlDOF_local;
u_f(local) = u0_f(local) + ds + 0.01;   % slightly past target

[g, h, ~] = strat.constraint(u_f, 0, u0_f, 0, [], [], ds);

expected_g = 0.01;   % u_f(local) - (u0_f(local) + ds)
if abs(g - expected_g) > 1e-12
    error('g = %g, expected %g', g, expected_g);
end

% h must be zeros except at ControlDOF_local
if abs(h(local) - 1) > 1e-12
    error('h(%d) = %g, expected 1', local, h(local));
end
off = h; off(local) = 0;
if norm(off) > 1e-12
    error('h has non-zero entries outside ControlDOF_local');
end
end

% ----------------------------------------------------------------
function ut6_5()
% adaptRadius: easy step (iters=2) → radius grows x1.5 up to ArcLengthMax.
%              hard step (iters > 0.75*maxIter) → radius shrinks x0.7.
maxIter = 20;

% --- easy step ---
strat_easy = RiksStrategy('ArcLengthRadius', 0.04, ...
    'ArcLengthMax', 1.0, 'ArcLengthMin', 1e-6);
r_before = strat_easy.ArcLengthRadius;
strat_easy.adaptRadius(2, maxIter);
r_after = strat_easy.ArcLengthRadius;

expected_r = min(r_before * 1.5, strat_easy.ArcLengthMax);
if abs(r_after - expected_r) > 1e-12
    error('Easy step: radius = %g, expected %g', r_after, expected_r);
end

% --- hard step (iters = 16 > 0.75*20 = 15) ---
strat_hard = RiksStrategy('ArcLengthRadius', 0.04, ...
    'ArcLengthMax', 1.0, 'ArcLengthMin', 1e-6);
r_before2 = strat_hard.ArcLengthRadius;
strat_hard.adaptRadius(16, maxIter);
r_after2 = strat_hard.ArcLengthRadius;

expected_r2 = max(r_before2 * 0.7, strat_hard.ArcLengthMin);
if abs(r_after2 - expected_r2) > 1e-12
    error('Hard step: radius = %g, expected %g', r_after2, expected_r2);
end

% --- ArcLengthMin clamp ---
strat_min = RiksStrategy('ArcLengthRadius', strat_hard.ArcLengthMin * 1.1, ...
    'ArcLengthMin', 0.001, 'ArcLengthMax', 1.0);
strat_min.adaptRadius(maxIter, maxIter);   % worst case
if strat_min.ArcLengthRadius < strat_min.ArcLengthMin - 1e-12
    error('Radius dropped below ArcLengthMin: %g < %g', ...
          strat_min.ArcLengthRadius, strat_min.ArcLengthMin);
end
end
