% UNIFIED_SOLVER_VERIFICATION_TEST
try
    fprintf('=== Initializing Unified Solver Verification (2x2 Mesh) ===\n');
    E = 210e3; nu = 0.3; t = 0.01;
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0,0,0], 1.0, 1.0);
    Pre.meshAllPatches(2, 2); 
    
    fixNodes = Pre.selectNodesOnPlane(1, 0, 1e-6);
    Pre.addBC(fixNodes, 1:6, 0, 'fix');
    tipNodes = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
    Pre.addNodalLoad(tipNodes, 3, -10, 'load'); % Small load
    
    opts = SolverOptions();
    opts.Tolerance = 1e-5; % Numerical floor for this element type
    Sol = FEM_Solver_Nonlinear(Pre, opts);
    
    % --- TEST 1: Standard Newton 2x2 ---
    fprintf('\n--- TEST 1: Standard Newton 2x2 ---\n');
    S1 = LoadingStage(1.0);
    S1.activateBC('fix'); S1.activateLoad('load');
    S1.strategy = StandardNewtonStrategy(0.25); % Multi-step
    Sol.solve({S1});
    assert(Sol.StepCount > 0, 'Should have completed converged steps');
    
    % --- TEST 2: PLASTIC REPLAY ---
    fprintf('\n--- TEST 2: PLASTIC 2x2 ---\n');
    Pre.setMaterialPlastic(100.0, 1000.0); % Yield=100, H=1000
    Sol = FEM_Solver_Nonlinear(Pre, opts);
    S1.strategy = StandardNewtonStrategy(0.05); % Small steps for plasticity
    Sol.solve({S1});
    
    Post = FEM_Postprocessor_v2(Pre, Sol);
    vm = Post.recoverField('von_mises', 1);
    fprintf('Step 1 VM Stress Mean: %.2f\n', mean(vm));
    
    fprintf('=== VERIFICATION SUCCESSFUL ===\n');
catch ME
    fprintf('*** VERIFICATION FAILED ***\n');
    fprintf('Error: %s\n', ME.message);
    rethrow(ME);
end
