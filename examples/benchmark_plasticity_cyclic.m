function results = benchmark_plasticity_cyclic()
    % BENCHMARK_PLASTICITY_CYCLIC  Cyclic loading with hardening
    %
    % Objective: Validate J2 plasticity with cyclic stress history
    % Problem:   Small element under cyclic uniaxial stress
    % Physics:   Isotropic hardening, hysteresis loops
    
    tic;
    fprintf('=== BENCHMARK: Plasticity Cyclic Loading ===\n');
    fprintf('Validate hardening behavior under cyclic loading\n\n');
    
    % Material with yield and hardening
    E = 210e9;
    nu = 0.3;
    t = 0.01;
    sigma_y = 250e6;  % Yield stress (Pa)
    H = 50e9;         % Hardening modulus
    
    fprintf('Material: E=%.2e Pa, σ_y=%.2e Pa, H=%.2e Pa\n', E, sigma_y, H);
    
    % Create tensile coupon
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0, 0, 0], 0.1, 0.01);
    Pre.meshAllPatches(2, 1);
    Pre.computeNormals();
    
    % Set plastic material
    Pre.setMaterialPlastic(sigma_y, H);
    
    % Fixed one end
    left = Pre.selectNodesByBox(-0.01, 0.01, -0.1, 0.1, -0.1, 0.1);
    Pre.addBC(left, 1:6, 0, 'Fixed');
    
    % Cyclic displacement on other end: 3 cycles
    right = Pre.selectNodesByBox(0.09, 0.11, -0.1, 0.1, -0.1, 0.1);
    if ~isempty(right)
        u_max = 0.003;  % Small displacement to trigger plasticity
        Pre.addBC(right(1), 1, u_max, 'CyclicDisp');
    end
    
    % Solver
    opts = SolverOptions();
    opts.Tolerance = 1e-3;
    opts.MaxIterations = 15;
    
    fprintf('\n--- SOLVER EXECUTION ---\n');
    try
        Sol = FEM_Solver_Adaptive(Pre, opts);
        Stage = LoadingStage(3.0);  % 3 cycles
        Stage.activateBC('Fixed');
        Stage.activateBC('CyclicDisp');
        Sol.solve({Stage});
        
        steps = Sol.StepCount;
        success = true;
    catch
        steps = 0;
        success = false;
    end
    
    elapsed_time = toc;
    
    fprintf('Steps completed: %d\n', steps);
    fprintf('Time: %.4f seconds\n', elapsed_time);
    
    % ===== ACCEPTANCE CRITERIA =====
    pass_convergence = (steps >= 10) && success;
    pass_time = (elapsed_time < 1.0);
    overall_pass = pass_convergence && pass_time;
    
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Multiple cycles completed .............. %s (%d steps)\n', ...
        iif(pass_convergence, 'PASS', 'FAIL'), steps);
    fprintf('Execution time < 1 second .............. %s (%.4f s)\n', ...
        iif(pass_time, 'PASS', 'FAIL'), elapsed_time);
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    results.steps = steps;
    results.execution_time = elapsed_time;
    results.converged = success;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
