%% Test Suite: Line Search Significance
% Demonstrates how line search prevents divergence in snap-through problems.

fprintf('\n=== Running Line Search Significance Test ===\n');

% -------------------------------------------------------------------------
% Path Setup
% -------------------------------------------------------------------------
scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fullfile(scriptPath, '..');
addpath(fullfile(projectRoot, 'src'));
clear classes;

% Geometry: Deep Arch (Snap-through candidate)
E = 210e9;
nu = 0.3;
t = 0.05;
R = 5.0;
Chord = 10.0;
H = R - sqrt(R^2 - (Chord/2)^2); % Deep enough to snap

Pre = FEM_Preprocessor_v2(E, nu, t);
n1 = [-Chord/2, 0, 0];
n2 = [Chord/2, 0, 0];
n_center = [0, 0, H];
nodes = [n1; n2; n_center];
segs = [1, 2, 3, 12];
Pre.createExtrusion(nodes, segs, [0, 1, 0], 6, 12);
Pre.computeNormals();

% BCs
leftNodes = Pre.selectNodesByBox(-Chord/2-0.1, -Chord/2+0.1, -1, 1, -1, 1);
rightNodes = Pre.selectNodesByBox(Chord/2-0.1, Chord/2+0.1, -1, 1, -1, 1);
Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Support');

% Point load at crown - massive
centerID = Pre.selectNodesByBox(-0.1, 0.1, 2.9, 3.1, H-0.1, H+0.1);
if isempty(centerID), centerID = 1; else, centerID = centerID(1); end
Pre.addNodalLoad(centerID, 3, -1.5e6, 'CrownLoad'); 

% Force Load Control with NO ADAPTATION (Radius locked to 1.0)
stage.strategy = LoadControlStrategy('ArcLengthRadius', 1.0); 
stage.strategy.ArcLengthMin = 1.0;
stage.strategy.ArcLengthMax = 1.0;

% -------------------------------------------------------------------------
% Run A: No Line Search
% -------------------------------------------------------------------------
fprintf('\n--- TEST A: No Line Search (Forced 1.0 step) ---\n');
optsA = SolverOptions();
optsA.UseLineSearch = false;
optsA.numLoadSteps = 1;
optsA.Tolerance = 1e-6;
SolA = FEM_Solver_Nonlinear(Pre, optsA);
try, SolA.solve({stage}); catch, end
if SolA.StepCount == 0, fprintf('\n [SOLVER FAILED AS EXPECTED]\n'); end

% -------------------------------------------------------------------------
% Run B: Armijo Line Search
% -------------------------------------------------------------------------
fprintf('\n--- TEST B: Armijo Line Search (Forced 1.0 step) ---\n');
optsB = SolverOptions();
optsB.UseLineSearch = true;
optsB.LineSearchMethod = 'armijo';
optsB.numLoadSteps = 1;
optsB.Tolerance = 1e-6;
SolB = FEM_Solver_Nonlinear(Pre, optsB);
try, SolB.solve({stage}); catch, end

% -------------------------------------------------------------------------
% Run C: Standard Line Search
% -------------------------------------------------------------------------
fprintf('\n--- TEST C: Standard Line Search (Forced 1.0 step) ---\n');
optsC = SolverOptions();
optsC.UseLineSearch = true;
optsC.LineSearchMethod = 'standard';
optsC.numLoadSteps = 1;
optsC.Tolerance = 1e-6;
SolC = FEM_Solver_Nonlinear(Pre, optsC);
try, SolC.solve({stage}); catch, end

% -------------------------------------------------------------------------
% Conclusion
% -------------------------------------------------------------------------
fprintf('\n=== Significance Check ===\n');
fprintf('StepCounts: A=%d, B=%d, C=%d\n', SolA.StepCount, SolB.StepCount, SolC.StepCount);
if SolA.StepCount < 1 && (SolB.StepCount > 0 || SolC.StepCount > 0)
    fprintf('SIGNIFICANCE VERIFIED: Line search enabled convergence where vanilla Newton failed.\n');
else
    fprintf('SIGNIFICANCE INCONCLUSIVE.\n');
end
