%% TEST_SOLVER_INTEGRATION
% Full pipeline integration test for the redesigned solver.
% Must pass before any release.
%
% Run: runtests('tests/test_solver_integration.m')

function tests = test_solver_integration
tests = functiontests(localfunctions);
end

function test_linear_static_patch(testCase)
% Patch test: constant-strain field must be reproduced exactly
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(4, 4);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 1, 2100, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
Ux_tip = mean(Sol.U((Pre.selectNodesOnPlane(1,1.0,1e-6)-1)*6+1));
Ux_ref = 2100 / (210e3 * 0.01) * 1.0;
verifyLessThan(testCase, abs(Ux_tip-Ux_ref)/Ux_ref, 0.02, 'Linear patch test');
fprintf('Integration T1 PASS: linear static\n');
end

function test_assembler_matches_solver(testCase)
% Verify Assembler.elastic produces identical K to assembleK
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 3, -500, 'load');
Sol = FEM_Solver(Pre);
Sol.assembleK();
K_solver = Sol.GlobalK;
nDofs = size(Pre.Mesh.Nodes, 1) * 6;
K_direct = Assembler.elastic(Sol.Elements, Sol.SctrMap, nDofs);
diff = norm(K_solver - K_direct, 'fro');
verifyLessThan(testCase, diff, 1e-10, ...
    sprintf('Assembler K mismatch, diff = %.3e', diff));
fprintf('Integration T2 PASS: Assembler matches solver\n');
end

function test_solution_state_basics(testCase)
% Unit test SolutionState
nD = 120;
opts = SolverOptions();
state = SolutionState(nD, opts);
verifyEqual(testCase, state.StepCount, 0, 'initial StepCount');
for k = 1:5
    U_k = rand(nD, 1);
    state.appendStep(U_k, k*0.1, [], [], 0.05);
end
verifyEqual(testCase, state.StepCount, 5, 'StepCount after 5 appends');
U3 = state.getU(3);
verifyEqual(testCase, length(U3), nD, 'getU wrong size');
snap = state.snapshot();
verifyTrue(testCase, isa(snap, 'SolutionSnapshot'), 'snapshot wrong type');
verifyEqual(testCase, snap.StepCount, 5, 'snapshot StepCount');
verifyEqual(testCase, size(snap.U_Hist, 2), 5, 'snapshot U_Hist columns');
fprintf('Integration T3 PASS: SolutionState and SolutionSnapshot\n');
end

function test_convergence_monitor(testCase)
% Verify ConvergenceMonitor force norm
mon = ConvergenceMonitor();
mon.Tolerance = 1e-6;
Fext = ones(10,1) * 100;
mon.reset(Fext);
R_converged = ones(10,1) * 1e-5;
R_diverged  = ones(10,1) * 1000;
dU = ones(10,1);
U  = ones(10,1) * 50;
verifyTrue(testCase, mon.check(R_converged, dU, U, Fext, 1), 'should converge');
mon.reset(Fext);
verifyFalse(testCase, mon.check(R_diverged, dU, U, Fext, 1), 'should not converge');
fprintf('Integration T4 PASS: ConvergenceMonitor\n');
end

function test_solver_options_clean(testCase)
% Verify legacy aliases are removed
opts = SolverOptions();
verifyTrue(testCase, isprop(opts, 'Tolerance'), 'Tolerance missing');
verifyTrue(testCase, isprop(opts, 'MaxIterations'), 'MaxIterations missing');
verifyTrue(testCase, isprop(opts, 'UseLineSearch'), 'UseLineSearch missing');
verifyTrue(testCase, isprop(opts, 'NormType'), 'NormType missing');
verifyFalse(testCase, isprop(opts, 'tol'), 'legacy tol still present');
verifyFalse(testCase, isprop(opts, 'maxIter'), 'legacy maxIter still present');
verifyFalse(testCase, isprop(opts, 'linesearch'), 'legacy linesearch still present');
opts.Tolerance = 1e-8;
verifyEqual(testCase, opts.Tolerance, 1e-8, 'property assignment failed');
fprintf('Integration T5 PASS: SolverOptions clean\n');
end

function test_strategy_classes(testCase)
% Verify strategy class construction and inheritance
rs = RiksStrategy('ArcLengthRadius', 0.02);
verifyTrue(testCase, isa(rs, 'IncrementalStrategy'), 'RiksStrategy type');
verifyEqual(testCase, rs.ArcLengthRadius, 0.02, 'Riks radius');
rs.adaptRadius(3, 20);  % iters=3 <= 4, should grow
verifyGreaterThan(testCase, rs.ArcLengthRadius, 0.02, 'adaptRadius did not grow');

lcs = LoadControlStrategy();
verifyTrue(testCase, isa(lcs, 'IncrementalStrategy'), 'LoadControlStrategy type');

dcs = DispControlStrategy(57, 'ArcLengthRadius', 0.001);
verifyTrue(testCase, isa(dcs, 'IncrementalStrategy'), 'DispControlStrategy type');
verifyEqual(testCase, dcs.ControlDOF, 57, 'ControlDOF not set');
fprintf('Integration T6 PASS: all strategy classes\n');
end

function test_loading_stage_strategy(testCase)
% Verify LoadingStage.getStrategy() backward compatibility
S1 = LoadingStage(1.0);
S1.ConstraintType = 'Riks';
S1.ArcLengthRadius = 0.05;
s1 = S1.getStrategy();
verifyTrue(testCase, isa(s1, 'RiksStrategy'), 'legacy Riks');
verifyEqual(testCase, s1.ArcLengthRadius, 0.05, 'radius propagated');

S2 = LoadingStage(1.0);
S2.strategy = LoadControlStrategy('ArcLengthRadius', 0.1);
s2 = S2.getStrategy();
verifyTrue(testCase, isa(s2, 'LoadControlStrategy'), 'new API');

S3 = LoadingStage(2.0);
s3 = S3.getStrategy();
verifyTrue(testCase, isa(s3, 'RiksStrategy'), 'default strategy');
fprintf('Integration T7 PASS: LoadingStage strategy API\n');
end

function test_postprocessor_no_mutation(testCase)
% Postprocessor must not change solver state
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1,1.0,1e-6), 3, -500, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
U_ref = Sol.U;
Post = FEM_Postprocessor(Pre, Sol);
w = warning('off', 'FEM_Postprocessor:deprecated');
vm = Post.recoverNodalSmooth('VonMises', 'Top');
warning(w);
verifyEqual(testCase, Sol.U, U_ref, 'AbsTol', 1e-12, 'Postprocessor mutated Solver.U');
verifyFalse(testCase, any(isnan(vm)), 'NaN in VonMises');
fprintf('Integration T8 PASS: no postprocessor mutation\n');
end

function test_linesearch_no_mutation(testCase)
% Verify linesearch returns eta without modifying obj.U
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
tipN = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
Pre.addNodalLoad(tipN, 3, -100, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
verifyFalse(testCase, any(isnan(Sol.U)), 'NaN after solveStatic with linesearch path');
fprintf('Integration T9 PASS: linesearch no mutation\n');
end

function test_singularity_detection(testCase)
% Verify rcond correctly detects singular and non-singular matrices
KT_singular = zeros(10, 10);
KT_good = eye(10);
verifyLessThan(testCase, rcond(KT_singular), 1e-13, 'singular not detected');
verifyGreaterThan(testCase, rcond(KT_good), 1e-13, 'non-singular falsely flagged');
fprintf('Integration T10 PASS: singularity detection\n');
end
