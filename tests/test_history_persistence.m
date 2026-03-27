% test_history_persistence.m
clear; clc;

% 1. Create a single element model
E = 200e9; nu = 0.3; t = 0.1;
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.Mesh.Nodes = [0,0,0; 1,0,0; 1,1,0; 0,1,0; 0,0,0.1; 1,0,0.1; 1,1,0.1; 0,1,0.1];
Pre.Mesh.Elements = int32(1:8);
Pre.Mesh.Normals = repmat([0,0,1], 8, 1);

% 2. Material: J2 Plasticity with VERY LOW Yield
sigY = 1e6; H = 0; % 1 MPa yield
Pre.setMaterialPlastic(sigY, H);

% 3. Solver
Sol = FEM_Solver_ArcLength(Pre, SolverOptions());

% 4. Mock Trial History
% We manually simulate what a solver iteration would produce
% 2x2x5 = 20 GPs
nGP = 20;
h_trial = struct('sigma', zeros(3,1), 'eps_p', ones(3,1)*0.01, 'p', 0.05);
TrialHist = {repmat(h_trial, nGP, 1)};

fprintf('--- UNIT TEST: History Persistence ---\n');
fprintf('Initial p: %.4f\n', Sol.Elements{1}.HistoryData(1).p);

% 5. Execute Commit
Sol.commitHistory(TrialHist);

% 6. Verify
final_p = Sol.Elements{1}.HistoryData(1).p;
fprintf('Final p:   %.4f\n', final_p);

if abs(final_p - 0.05) < 1e-6
    fprintf('[PASS] History committed successfully.\n');
else
    fprintf('[FAIL] History NOT committed.\n');
end
