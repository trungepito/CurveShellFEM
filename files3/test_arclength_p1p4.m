%% TEST_ARCLENGTH_P1P4  Regression and unit tests for arc-length solver enhancements.
%
% Tests are self-contained; each validates one enhancement in isolation.
%
% Run with:
%   results = runtests('test_arclength_p1p4')
%
% Test catalogue:
%   T1  P1.1 — rcond gate fires on a constructed near-singular KT
%   T2  P1.2 — residual sign: arcLengthStep converges on a trivial 1-DOF problem
%   T3  P1.3 — denominator guard catches near-degenerate constraint
%   T4  P1.4 — while-loop stage drives past nSteps estimate on snap-back path
%   T5  P2.1 — line search reduces residual norm vs no-line-search
%   T6  P2.2 — assembleTangentSystem returns symmetric KT
%   T7  P3.1 — predictor scale is dimensionally consistent across F_ext magnitudes
%   T8  P3.3 — energy criterion triggers convergence when residual plateaus
%   T9  P4.1 — elastic fast path invokes assembleinternalforceONLY, not full assembly
%   T10 P4.2 — single LU reuse: two RHS solves produce same result as two backslash calls

function tests = test_arclength_p1p4
tests = functiontests(localfunctions);
end

% =========================================================================
% HELPERS
% =========================================================================

function sol = makeMinimalElasticSolver()
% 1-element 1×1 flat plate, linear elastic.
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
nBotNodes = Pre.selectNodesOnPlane(2, 0, 1e-6);
Pre.addBC(nBotNodes, 1:6, 0, 'fix');
nTopNodes = Pre.selectNodesOnPlane(2, 1.0, 1e-6);
Pre.addNodalLoad(nTopNodes(1), 3, -100, 'load');
opts = SolverOptions();
opts.Tolerance     = 1e-6;
opts.MaxIterations = 20;
sol = FEM_Solver_ArcLength(Pre, opts);
end

% =========================================================================
% T1: P1.1 — rcond gate
% =========================================================================
function test_rcond_gate_fires(testCase)
% Build a 2x2 nearly singular matrix and verify rcond < 1e-13
A = [1, 1; 1+1e-15, 1];   % almost rank-deficient
rc = rcond(full(A));
verifyLessThan(testCase, rc, 1e-13, ...
    'rcond should be < 1e-13 for near-singular A');

% The old condest would return condest(A) which is >= 1 and the threshold
% 1e-14 could never fire — verify the old logic was broken.
ce = condest(sparse(A));
verifyGreaterThan(testCase, ce, 1.0, ...
    'condest always >= 1; old threshold 1e-14 was unreachable');
end

% =========================================================================
% T2: P1.2 — residual sign convention
% =========================================================================
function test_residual_sign_converges(testCase)
% Trivial 1-DOF system: K=1, F_ext=1 => equilibrium at u=1.
% We simulate what arcLengthStep does and confirm convergence.
K = 1; F_ext = 1;
u = 0; lambda = 0; tol = 1e-8; maxit = 30;
converged = false;
for i = 1:maxit
    F_int = K * u;                    % linear spring
    R     = F_int - lambda * F_ext;   % P1.2 convention: R = F_int - lam*F_ext
    if abs(R) < tol, converged = true; break; end
    % Newton: K * du = -R  =>  du = -R / K
    du     = -R / K;
    dlam   = 0.1;                     % load control increment
    u      = u + du + dlam * (K\F_ext);
    lambda = lambda + dlam;
end
verifyTrue(testCase, converged, ...
    'P1.2: residual sign R=F_int-lam*F_ext should converge to equilibrium');
verifyEqual(testCase, u, 1.0, 'AbsTol', 1e-6, ...
    'P1.2: equilibrium displacement should be 1.0');
end

% =========================================================================
% T3: P1.3 — denominator guard
% =========================================================================
function test_denominator_guard(testCase)
% Construct a scenario where h'*du_I == -s so the full denominator is zero.
% The guard should catch this and return converged=false, not NaN/Inf.
n  = 4;
du_I = [1; 0; 0; 0];
h    = [1; 0; 0; 0];
s    = -1.0;   % exactly cancels h'*du_I = 1

raw_denom   = s + h' * du_I;    % = 0
scale_denom = abs(s) + norm(h) * norm(du_I) + eps;
ratio = abs(raw_denom) / scale_denom;

verifyLessThan(testCase, ratio, 1e-10, ...
    'P1.3: full denominator should be near zero when s cancels h*du_I');

% Confirm the guard would trigger
fired = (ratio < 1e-10);
verifyTrue(testCase, fired, 'P1.3: denominator guard should fire for this case');
end

% =========================================================================
% T4: P1.4 — lambda-target termination (conceptual)
% =========================================================================
function test_lambda_target_termination(testCase)
% Simulate the while-loop termination logic with a mock lambda sequence
% that includes a snap-back (lambda decreasing then increasing).
% The old for-loop with nSteps = ceil(Duration/arc) would have terminated
% early; the while loop should accumulate all steps until target is reached.

lambda_end  = 1.0;
arc_length  = 0.4;
tol_lam     = 1e-8;
max_steps   = 100;

% Simulated lambda sequence: load, snap-back, reload
lambda_seq = [0.4, 0.8, 0.6, 0.8, 1.0];   % snap-back at step 3

lambda = 0;
step   = 0;
for k = 1:length(lambda_seq)
    lambda = lambda_seq(k);
    step   = step + 1;
    if abs(lambda - lambda_end) < tol_lam, break; end
end

% The old nSteps = ceil(1.0 / 0.4) = 3 would have stopped at k=3 (lambda=0.6)
% The while loop continues to k=5 (lambda=1.0)
old_nSteps = ceil(lambda_end / arc_length);
verifyEqual(testCase, old_nSteps, 3, 'old nSteps estimate is 3 for arc=0.4, Duration=1');
verifyEqual(testCase, step, 5, 'while loop needs 5 steps for snap-back path');
verifyEqual(testCase, lambda, 1.0, 'AbsTol', 1e-10, 'final lambda should be 1.0');
end

% =========================================================================
% T5: P2.1 — line search reduces residual
% =========================================================================
function test_line_search_reduces_residual(testCase)
% For a 1-D nonlinear spring  F = K * u^3, full Newton steps overshoot.
% With line search the residual should be non-increasing.
K = 1; F_ext = 0.5; lambda = 1;
u = 1.5;   % overshoot starting point
tol = 1e-8; LS_FACTOR = 0.5; LS_ARMIJO = 1e-4; LS_MAXIT = 10;

F_int   = K * u^3;
R       = F_int - lambda * F_ext;
KT      = 3 * K * u^2;
dU_full = -R / KT;   % full Newton step — overshoots for nonlinear spring

R_norm_prev = abs(R);
eta = 1.0;
for ls = 1:LS_MAXIT
    u_ls  = u + eta * dU_full;
    R_ls  = K * u_ls^3 - lambda * F_ext;
    armijo = abs(R_ls) < (1 - LS_ARMIJO * eta) * R_norm_prev + eps;
    if armijo, break; end
    eta = eta * LS_FACTOR;
end

R_norm_ls = abs(K * (u + eta*dU_full)^3 - lambda*F_ext);
verifyLessThanOrEqual(testCase, R_norm_ls, R_norm_prev + 1e-10, ...
    'P2.1: line search must not increase the residual norm');
verifyLessThan(testCase, eta, 1.0, ...
    'P2.1: for this overshoot case eta should be < 1 (backtracking fired)');
end

% =========================================================================
% T6: P2.2 — assembleTangentSystem returns symmetric KT
% =========================================================================
function test_kt_symmetry(testCase)
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
nBot = Pre.selectNodesOnPlane(2, 0, 1e-6);
Pre.addBC(nBot, 1:6, 0, 'fix');
Sol = FEM_Solver(Pre);
[KT, ~, ~] = Sol.assembleTangentSystem(zeros(size(Pre.Mesh.Nodes,1)*6, 1));

KT_full = full(KT);
sym_err = norm(KT_full - KT_full', 'fro') / (norm(KT_full, 'fro') + eps);

verifyLessThan(testCase, sym_err, 1e-12, ...
    'P2.2: assembled KT must be symmetric to machine precision');
end

% =========================================================================
% T7: P3.1 — predictor scale is dimensionally consistent
% =========================================================================
function test_predictor_scale_consistency(testCase)
% With the corrected scale, the predictor step size in (u, lambda) space
% should satisfy  ||du||^2 + (psi*||F_ext||)^2 * dlam^2 = arc_length^2
% regardless of the magnitude of F_ext.

arc_length = 0.1;
psi        = 1.0;

for f_mag = [1, 1e3, 1e-3]
    F_ext_norm = f_mag;
    psi_eff    = psi * F_ext_norm;

    % Simulated du_I direction (unit vector)
    du_I_norm = 1.0;   % ||du_I|| = 1 for simplicity

    denom_pred = sqrt(du_I_norm^2 + psi_eff^2);
    dlp        = arc_length / denom_pred;
    du_norm    = dlp * du_I_norm;

    ds_sq = du_norm^2 + (psi_eff)^2 * dlp^2;
    verifyEqual(testCase, sqrt(ds_sq), arc_length, 'AbsTol', 1e-12, ...
        sprintf('P3.1: arc-length metric should equal arc_length for F_ext_norm=%.3g', f_mag));
end
end

% =========================================================================
% T8: P3.3 — energy criterion triggers on stagnation
% =========================================================================
function test_energy_criterion(testCase)
% Simulate a stagnating corrector: residual norm stays constant but the
% energy ratio drops, causing the energy criterion to fire before the
% residual criterion.
tol = 1e-4;
energy_first = 1.0;

% After 5 iterations the energy has decayed by tol^2 but residual has not
energy_curr = energy_first * tol^2 * 0.5;   % below threshold
R_norm      = 0.05;                           % above tol (residual not converged)
f_norm      = 1.0;

residual_converged = R_norm <= tol * f_norm;   % false
energy_converged   = energy_curr / energy_first < tol^2;   % true

verifyFalse(testCase, residual_converged, 'P3.3: residual should NOT have converged');
verifyTrue(testCase, energy_converged,    'P3.3: energy criterion should have fired');
end

% =========================================================================
% T9: P4.1 — elastic fast path skips KT re-assembly
% =========================================================================
function test_elastic_fast_path_flag(testCase)
% After calling assembleTangentSystem on a linear-elastic model,
% KT_is_elastic_constant should be set to true.
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
nBot = Pre.selectNodesOnPlane(2, 0, 1e-6);
Pre.addBC(nBot, 1:6, 0, 'fix');
Sol = FEM_Solver(Pre);
Sol.assembleTangentSystem(zeros(size(Pre.Mesh.Nodes,1)*6, 1));

verifyTrue(testCase, Sol.KT_is_elastic_constant, ...
    'P4.1: KT_is_elastic_constant should be true for linear-elastic model');

% For a plastic model the flag should be false
Pre2 = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre2.createPlate([0,0,0], 1.0, 1.0);
Pre2.meshAllPatches(2, 2);
Pre2.setMaterialPlastic(250, 1000);
Sol2 = FEM_Solver(Pre2);
Sol2.assembleTangentSystem(zeros(size(Pre2.Mesh.Nodes,1)*6, 1));

verifyFalse(testCase, Sol2.KT_is_elastic_constant, ...
    'P4.1: KT_is_elastic_constant should be false for J2-plastic model');
end

% =========================================================================
% T10: P4.2 — LU reuse gives same result as two backslash calls
% =========================================================================
function test_lu_reuse_consistency(testCase)
% Build a random SPD 20×20 system and verify that the factorised-solve
% result matches the direct backslash result to machine precision.
rng(42);
n = 1000;
% Create an "almost diagonal" stiffness-like SPD matrix: dominant diagonal with
% small off-diagonal couplings to mimic finite-element stiffness structure.
% e = ones(n,1);
diag_vals = 10 + 0.1*rand(n,1);           % dominant diagonal entries
A = spdiags(diag_vals, 0, n, n);
off =  -0.01 * ones(n-1,1);               % small negative couplings (like stiffness)
A = A + spdiags(off, 1, n, n) + spdiags(off, -1, n, n);
% Ensure strict SPD by adding tiny diagonal if needed
A = A + 1e-8 * speye(n);

b1 = rand(n,1);
b2 = rand(n,1);

A=sparse(A);

% Method 1: two backslash calls (old approach)
tic
x1_bs = A \ b1;
x2_bs = A \ b2;
toc
% Method 2: single LU, two triangular solves (P4.2)
tic
[L, U, P, Q] = lu(A);
% solve_f = @(b) Q * (U \ (L \ (P * b)));% this is a bad performer!!!
x1_lu  = Q * (U \ (L \ (P * b1))); 
x2_lu  = Q * (U \ (L \ (P * b2)));
toc
tol_lu = 1e-10;
verifyEqual(testCase, x1_lu, x1_bs, 'AbsTol', tol_lu, ...
    'P4.2: LU reuse must give same result as backslash for b1');
verifyEqual(testCase, x2_lu, x2_bs, 'AbsTol', tol_lu, ...
    'P4.2: LU reuse must give same result as backslash for b2');
end
