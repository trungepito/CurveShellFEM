% verify_plastic_viz.m
clear; clc;

% 1. Run Audit Case (Plastic Snap-through)
% Reuse the setup from audit_phase5_plastic_snapthrough.m
% We force yielding with a large load
sigY = 50e6; H = 2e9; P = -50e6;
E = 200e9; nu = 0.3; t = 0.05;
Pre = FEM_Preprocessor_v2(E, nu, t);
profile = [10,0,0; 8,0,1.34; 0,0,1.34]; % Simple arch
Pre.createExtrusion(profile, [1,2,3,4], [0,1,0], 5.0, 4);
Pre.setMaterialPlastic(sigY, H);
Pre.addBC(Pre.selectNodesByBox(-10,10,-1,6,-1,10), 1:3, 0, 'Pins');
Pre.addPressureLoad((1:size(Pre.Mesh.Elements,1))', P, 'Load');

Sol = FEM_Solver_ArcLength(Pre, SolverOptions());
S1 = LoadingStage(1.0); S1.activateLoad('Load'); S1.activateBC('Pins');
Sol.solve({S1});

% 2. Visualization
Post = FEM_Postprocessor(Pre, Sol);
fprintf('Generating Plastic Yield Plot...\n');
try
    Post.plotPlasticYield();
    fprintf('[PASS] plotPlasticYield executed successfully.\n');
catch ME
    fprintf('[FAIL] Plotting error: %s\n', ME.message);
end
