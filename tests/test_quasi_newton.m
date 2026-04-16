%% Test Suite: Quasi-Newton acceleration and Diagnostics
% compares Standard Newton vs L-BFGS for a simple geometric nonlinear plate.

fprintf('\n=== Running Quasi-Newton Verification ===\n');

% -------------------------------------------------------------------------
% Path Setup (Avoid shadowing and ensure visibility)
% -------------------------------------------------------------------------
scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fullfile(scriptPath, '..');
addpath(fullfile(projectRoot, 'src'));
% In MATLAB, adding the 'src' directory is enough for @folders to be found.

% Clear classes to ensure latest SolverOptions is used
clear classes; 

% -------------------------------------------------------------------------
% Setup
% -------------------------------------------------------------------------
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(4, 4);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'Support');
tipN = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
Pre.addNodalLoad(tipN, 3, -1500, 'load'); % high load for nonlinearity

stage = LoadingStage(1.0);
stage.activateBC('Support');
stage.activateLoad('load');

% -------------------------------------------------------------------------
% Run 1: Standard Newton (Reference)
% -------------------------------------------------------------------------
fprintf('\n--- TEST 1: Standard Newton (Pure) ---\n');
opts1 = SolverOptions();
opts1.UseQuasiNewton = false;
opts1.numLoadSteps = 4;
Sol1 = FEM_Solver_Nonlinear(Pre, opts1);

tic;
Sol1.solve({stage});
t1 = toc;
U1 = Sol1.U;

% -------------------------------------------------------------------------
% Run 2: L-BFGS Accelerated
% -------------------------------------------------------------------------
fprintf('\n--- TEST 2: L-BFGS Accelerated ---\n');
opts2 = SolverOptions();
opts2.UseQuasiNewton = true;
opts2.LBFGSHistory = 5;
opts2.numLoadSteps = 4;
Sol2 = FEM_Solver_Nonlinear(Pre, opts2);

tic;
Sol2.solve({stage});
t2 = toc;
U2 = Sol2.U;

% -------------------------------------------------------------------------
% Comparisons
% -------------------------------------------------------------------------
fprintf('\n=== Results Comparison ===\n');
diff21 = norm(U2 - U1) / norm(U1);

fprintf('L-BFGS vs Reference Error:   %.2e\n', diff21);
fprintf('Newton Time:                 %.3f s\n', t1);
fprintf('L-BFGS Time:                 %.3f s\n', t2);

% Accuracy Threshold
assert(diff21 < 1e-5, 'L-BFGS Accuracy Failed');

fprintf('\nSUCCESS: Quasi-Newton and Diagnostics verification complete.\n');
