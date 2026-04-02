function results = benchmark_plastic_geometric_combined()
    % BENCHMARK_PLASTIC_GEOMETRIC_COMBINED  Combined plastic + geometric NL
    %
    % Objective: Combine material and geometric nonlinearity
    % Problem:   Cantilever with plasticity in large displacement regime
    % Physics:   Geometric NL + J2 plasticity, convergence should be slow
    
    tic;
    fprintf('=== BENCHMARK: Plasticity + Geometric NL ===\n');
    fprintf('Combined material and geometric nonlinearity\n\n');
    
    E = 210e9;
    nu = 0.3;
    t = 0.01;
    sigma_y = 100e6;  % Lower yield to trigger plasticity faster
    H = 10e9;
    
    fprintf('Material: E=%.2e Pa, σ_y=%.2e Pa (low to trigger plasticity)\n', E, sigma_y);
    fprintf('Large displacement: u/L ≈ 0.3 (strong geometric NL)\n');
    
    % Create cantilever  
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0, 0, 0], 1.0, 0.1);
    Pre.meshAllPatches(10, 2);
    Pre.computeNormals();
    Pre.setMaterialPlastic(sigma_y, H);
    
    % Fixed end
    left = Pre.selectNodesByBox(-0.01, 0.01, -0.1, 0.2, -0.1, 0.1);
    Pre.addBC(left, 1:6, 0, 'Fixed');
    
    % Displacement control at tip
    right = Pre.selectNodesByBox(0.99, 1.01, -0.1, 0.2, -0.1, 0.1);
    if ~isempty(right)
        u_tip = 0.2;  % 20% of length - large displacement
        Pre.addBC(right(1), 2, u_tip, 'TipDisp');
    end
    
    opts = SolverOptions();
    opts.Tolerance = 1e-3;
    opts.MaxIterations = 20;
    opts.InitialDt = 0.1;  % More conservative stepping
    
    fprintf('\n--- SOLVER EXECUTION ---\n');
    try
        Sol = FEM_Solver_Adaptive(Pre, opts);
        Stage = LoadingStage(1.0);
        Stage.activateBC('Fixed');
        Stage.activateBC('TipDisp');
        Sol.solve({Stage});
        
        steps = Sol.StepCount;
        if isfield(Sol, 'ConvergenceHistory')
            mean_iter = mean(Sol.ConvergenceHistory(1:steps));
            max_iter = max(Sol.ConvergenceHistory(1:steps));
        else
            mean_iter = 0;
            max_iter = 0;
        end
        success = true;
        
        % Extract tip displacement
        tip_node = right(1);
        u_actual = Sol.U((tip_node-1)*6 + 2);
    catch
        steps = 0;
        mean_iter = 0;
        max_iter = 0;
        success = false;
        u_actual = 0;
    end
    
    elapsed_time = toc;
    
    fprintf('Steps completed: %d\n', steps);
    fprintf('Mean iterations: %.1f, Max: %d\n', mean_iter, max_iter);
    fprintf('Tip displacement: %.4f m (target: %.4f m)\n', u_actual, u_tip);
    fprintf('Time: %.4f seconds\n', elapsed_time);
    
    % ===== ACCEPTANCE CRITERIA =====
    pass_displacement = abs(u_actual - u_tip) / u_tip < 0.1;  % 10% tolerance
    pass_convergence = (max_iter <= 30);  % More iterations expected for combined NL
    pass_steps = (steps >= 5);
    overall_pass = pass_displacement && pass_convergence && pass_steps && success;
    
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Final displacement within 10%% ......... %s (%.4f vs %.4f m)\n', ...
        iif(pass_displacement, 'PASS', 'FAIL'), u_actual, u_tip);
    fprintf('Convergence rate (max ≤ 30 iter) ....... %s (max %d)\n', ...
        iif(pass_convergence, 'PASS', 'FAIL'), max_iter);
    fprintf('Multiple steps completed (≥ 5) ........ %s (%d steps)\n', ...
        iif(pass_steps, 'PASS', 'FAIL'), steps);
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    results.displacement_final = u_actual;
    results.displacement_target = u_tip;
    results.steps = steps;
    results.mean_iterations = mean_iter;
    results.max_iterations = max_iter;
    results.execution_time = elapsed_time;
    results.converged = success;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
