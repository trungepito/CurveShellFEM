%% Test Suite: Line Search Options
% Compares 'standard' vs 'armijo' line search methods.

fprintf('\n=== Running Line Search Verification ===\n');

% -------------------------------------------------------------------------
% Path Setup
% -------------------------------------------------------------------------
scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fullfile(scriptPath, '..');
addpath(fullfile(projectRoot, 'src'));
clear classes;

% -------------------------------------------------------------------------
% Setup a hard problem (buckling-prone plate with large step)
% -------------------------------------------------------------------------
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'Support');
tipN = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
Pre.addNodalLoad(tipN, 3, -2000, 'load'); % High load

stage = LoadingStage(1.0);
stage.activateBC('Support');
stage.activateLoad('load');

% -------------------------------------------------------------------------
% Run 1: Standard Line Search
% -------------------------------------------------------------------------
fprintf('\n--- TEST 1: Standard Line Search ---\n');
opts1 = SolverOptions();
opts1.UseLineSearch = true;
opts1.LineSearchMethod = 'standard';
opts1.numLoadSteps = 2; % Large steps to force line search
Sol1 = FEM_Solver_Nonlinear(Pre, opts1);

Sol1.solve({stage});
U1 = Sol1.U;

% -------------------------------------------------------------------------
% Run 2: Armijo Line Search
% -------------------------------------------------------------------------
fprintf('\n--- TEST 2: Armijo Line Search ---\n');
opts2 = SolverOptions();
opts2.UseLineSearch = true;
opts2.LineSearchMethod = 'armijo';
opts2.numLoadSteps = 2; % Large steps to force line search
Sol2 = FEM_Solver_Nonlinear(Pre, opts2);

Sol2.solve({stage});
U2 = Sol2.U;

% -------------------------------------------------------------------------
% Run 3: No Line Search (should ideally take more iterations or fail)
% -------------------------------------------------------------------------
fprintf('\n--- TEST 3: No Line Search ---\n');
opts3 = SolverOptions();
opts3.UseLineSearch = false;
opts3.numLoadSteps = 2;
Sol3 = FEM_Solver_Nonlinear(Pre, opts3);

Sol3.solve({stage});
U3 = Sol3.U;

% -------------------------------------------------------------------------
% Comparisons
% -------------------------------------------------------------------------
fprintf('\n=== Results Comparison ===\n');
diff21 = norm(U2 - U1) / norm(U1);
diff31 = norm(U3 - U1) / norm(U1);

fprintf('Armijo vs Standard Error:   %.2e\n', diff21);
fprintf('No LS vs Standard Error:    %.2e\n', diff31);

assert(diff21 < 1e-6, 'Line search methods disagreed on final displacement');

fprintf('\nSUCCESS: Line search options verification complete.\n');
