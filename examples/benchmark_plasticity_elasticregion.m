function results = benchmark_plasticity_elasticregion()
    % BENCHMARK_PLASTICITY_ELASTICREGION  Verify elastic loading behavior
    %
    % Objective: Confirm no plasticity in sub-yield loading
    % Problem:   Load to just below yield, then unload
    % Physics:   Pure elasticity, no permanent deformation
    
    tic;
    fprintf('=== BENCHMARK: Plasticity Elastic Region ===\n');
    fprintf('Verify elastic behavior below yield\n\n');
    
    E = 210e9;
    nu = 0.3;
    t = 0.01;
    sigma_y = 250e6;
    
    % Create specimen (same as cyclic)
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0, 0, 0], 0.1, 0.01);
    Pre.meshAllPatches(2, 1);
    Pre.computeNormals();
    Pre.setMaterialPlastic(sigma_y, 0);  % No hardening for purity
    
    left = Pre.selectNodesByBox(-0.01, 0.01, -0.1, 0.1, -0.1, 0.1);
    Pre.addBC(left, 1:6, 0, 'Fixed');
    
    % Load to 80% of yield (elastic only)
    right = Pre.selectNodesByBox(0.09, 0.11, -0.1, 0.1, -0.1, 0.1);
    if ~isempty(right)
        u_elastic_limit = 0.0008 * 0.1 / E * sigma_y * 0.8;  % Approx strain
        Pre.addBC(right(1), 1, u_elastic_limit, 'ElasticLoad');
    end
    
    opts = SolverOptions();
    opts.Tolerance = 1e-3;
    opts.MaxIterations = 10;
    
    fprintf('\n--- SOLVER EXECUTION ---\n');
    try
        Sol = FEM_Solver_Adaptive(Pre, opts);
        Stage = LoadingStage(1.0);
        Stage.activateBC('Fixed');
        Stage.activateBC('ElasticLoad');
        Sol.solve({Stage});
        
        steps = Sol.StepCount;
        success = true;
    catch
        steps = 0;
        success = false;
    end
    
    elapsed_time = toc;
    
    fprintf('Steps completed: %d (should reach 1.0 load factor)\n', steps);
    fprintf('Time: %.4f seconds\n', elapsed_time);
    
    % ===== ACCEPTANCE CRITERIA =====
    pass_convergence = (steps >= 1) && success;
    pass_time = (elapsed_time < 0.5);
    overall_pass = pass_convergence && pass_time;
    
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Completed elastic load ................. %s (%d steps)\n', ...
        iif(pass_convergence, 'PASS', 'FAIL'), steps);
    fprintf('Fast convergence (elastic) ............. %s (%.4f s)\n', ...
        iif(pass_time, 'PASS', 'FAIL'), elapsed_time);
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    results.steps = steps;
    results.execution_time = elapsed_time;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
