function results = benchmark_quasi_linear_weak_nonlinearity()
    % BENCHMARK_QUASI_LINEAR_WEAK_NONLINEARITY   Solver efficiency in weak-NL regime
    %
    % Objective: Validate nonlinear solver convergence in nearly-linear regime
    % Problem:   Small cantilever, geometric NL enabled, but u/L << 1 (weak effect)
    % Physics:   Geometric nonlinearity present but effects minimal
    % Solver:    FEM_Solver_Adaptive (should converge very rapidly, 1-2 iter/step)
    % Expected:  Fast convergence, displacement ~linear estimate ±0.3%
    
    tic;
    fprintf('=== BENCHMARK: Quasi-Linear Path (Weak Nonlinearity) ===\n');
    fprintf('Purpose: Validate solver robustness in nearly-linear regime\n\n');
    
    % Geometry (same as B1 linear cantilever, but light loading)
    L = 1.0;           % Length (m)
    W = 0.1;           % Width (m)
    H = 0.1;           % Height (m)
    t = 0.05;          % Thickness (plate model)
    
    % Material
    E = 210e9;         % Young's modulus (Pa)
    nu = 0.3;          % Poisson's ratio
    
    % Loading (10% of standard load to ensure weak NL)
    P_reference = 1000;  % Reference load
    P_small = 0.1 * P_reference;  % 100 N (small)
    
    % Expected linear displacement
    I = (W * H^3) / 12;
    delta_linear_expected = (P_small * L^3) / (3 * E * I);
    
    fprintf('Material: E = %.2e Pa,  ν = %.3f\n', E, nu);
    fprintf('Geometry: L = %.3f m, W = %.3f m, H = %.3f m\n', L, W, H);
    fprintf('Loading: P = %.0f N (10%% of reference, weak NL regime)\n', P_small);
    fprintf('Expected linear displacement: %.3f mm\n', delta_linear_expected * 1000);
    fprintf('Problem size ratio u/L = %.4f (very small, << 1)\n', delta_linear_expected / L);
    
    % Create and mesh
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0, 0, 0], L, W);
    Pre.meshAllPatches(10, 2);
    Pre.computeNormals();
    
    % Fixed end
    fixedNodes = Pre.selectNodesByBox(-0.01, 0.01, -1, 1, -1, 1);
    Pre.addBC(fixedNodes, 1:6, 0, 'Fixed');
    
    % Tip load
    tipNodes = Pre.selectNodesByBox(L-0.01, L+0.01, W/2-0.05, W/2+0.05, -1, 1);
    Pre.addNodalLoad(tipNodes(1), 2, P_small, 'TipLoad');
    
    % Solve with adaptive method (will converge quickly in weak NL)
    opts = SolverOptions();
    opts.Tolerance = 1e-4;
    opts.MaxIterations = 20;
    opts.InitialDt = 0.05;
    
    fprintf('\n--- SOLVER EXECUTION (20 load steps, weak NL) ---\n');
    
    Sol = FEM_Solver_Adaptive(Pre, opts);
    Stage = LoadingStage(P_small);
    Stage.activateBC('Fixed');
    Stage.activateLoad('TipLoad');
    
    Sol.solve({Stage});
    
    elapsed_time = toc;
    
    % Extract results
    tipNode = tipNodes(1);
    u_final = Sol.U((tipNode-1)*6 + 2);
    steps = Sol.StepCount;
    
    fprintf('Steps completed: %d\n', steps);
    fprintf('Final tip displacement: %.6e m = %.4f mm\n', u_final, u_final * 1000);
    fprintf('Linear estimate: %.6e m = %.4f mm\n', delta_linear_expected, delta_linear_expected * 1000);
    
    error_percent = abs(u_final - delta_linear_expected) / delta_linear_expected * 100;
    fprintf('Error vs. linear: %.3f %%\n', error_percent);
    fprintf('Execution time: %.4f s\n', elapsed_time);
    
    % Acceptance criteria
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    
    pass_steps = (steps >= 10);
    pass_displacement = (error_percent < 1.0);  % Within 1% of linear
    pass_time = (elapsed_time < 1.0);
    
    fprintf('Steps ≥ 10 ......................... %s (completed: %d)\n', ...
        iif(pass_steps, 'PASS', 'FAIL'), steps);
    fprintf('Displacement error < 1.0%% ......... %s (error: %.3f%%)\n', ...
        iif(pass_displacement, 'PASS', 'FAIL'), error_percent);
    fprintf('Execution time < 1.0 s ............ %s (time: %.4f s)\n', ...
        iif(pass_time, 'PASS', 'FAIL'), elapsed_time);
    
    overall_pass = pass_steps && pass_displacement && pass_time;
    
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % Output
    results.geometry = struct('L', L, 'W', W, 'H', H, 't', t);
    results.material = struct('E', E, 'nu', nu);
    results.loading = struct('P', P_small);
    results.u_FEM = u_final;
    results.u_linear = delta_linear_expected;
    results.error_percent = error_percent;
    results.steps = steps;
    results.execution_time = elapsed_time;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end

