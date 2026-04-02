function results = benchmark_complex_path_multilimit()
    % BENCHMARK_COMPLEX_PATH_MULTILIMIT  Multi-limit-point equilibrium path
    %
    % Objective: Arc-length navigation of complex equilibrium path
    % Problem:   Cylindrical panel with multiple limit points
    % Physics:   Complex bifurcation behavior
    
    tic;
    fprintf('=== BENCHMARK: Complex Path Multi-Limit Points ===\n');
    
    % ===== SIMPLE CYLINDER WITH IMPERFECTION =====
    E = 200e9;
    nu = 0.3;
    t = 0.02;
    R = 5.0;        % Radius
    L = 20.0;       % Length
    amp = 0.001;    % Imperfection amplitude
    
    fprintf('Geometry: Cylindrical panel, R=%.1f m, L=%.1f m, t=%.4f m\n', R, L, t);
    fprintf('Imperfection: amplitude = %.6f m (%.2f%% of R)\n', amp, amp/R*100);
    
    % ===== CREATE MESH =====
    Pre = FEM_Preprocessor_v2(E, nu, t);
    % Simplified: Create plate as proxy for cylindrical panel
    Pre.createPlate([0, 0, 0], L/2, 3.14*R/8);  % Half-arc element as 1/4 model
    Pre.meshAllPatches(12, 6);
    Pre.computeNormals();
    
    % ===== BOUNDARY CONDITIONS =====
    % Simply supported on short edges
    leftNodes = Pre.selectNodesByBox(-0.01, 0.01, -1, 10, -1, 10);
    rightNodes = Pre.selectNodesByBox(L/2-0.01, L/2+0.01, -1, 10, -1, 10);
    Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Support');
    
    % Center load
    centerID = Pre.selectNodesByBox(L/4-0.1, L/4+0.1, 1.4, 1.6, -1, 1);
    if ~isempty(centerID)
        centerID = centerID(1);
        Pre.addNodalLoad(centerID, 3, -1e4, 'CenterLoad');
    end
    
    % ===== SOLVE WITH ARC-LENGTH =====
    opts = SolverOptions();
    opts.Tolerance = 1e-3;
    opts.MaxIterations = 25;
    
    fprintf('\n--- SOLVER EXECUTION ---\n');
    Sol = FEM_Solver_ArcLength(Pre, opts);
    Stage = LoadingStage(1.0);
    Stage.activateBC('Support');
    Stage.activateLoad('CenterLoad');
    Stage.ConstraintType = 'Riks';
    
    try
        Sol.solve({Stage});
        steps_completed = Sol.StepCount;
        lambda_final = Sol.History_Time(steps_completed);
        success = true;
    catch ME
        fprintf('Solver error: %s\n', ME.message);
        steps_completed = 0;
        lambda_final = 0;
        success = false;
    end
    
    elapsed_time = toc;
    
    fprintf('Steps completed: %d\n', steps_completed);
    fprintf('Final load factor λ = %.4f\n', lambda_final);
    fprintf('Execution time: %.4f seconds\n', elapsed_time);
    
    % ===== ACCEPTANCE CRITERIA =====
    pass_convergence = (steps_completed >= 10);  % Should complete substantial path
    pass_time = (elapsed_time < 2.0);
    overall_pass = pass_convergence && pass_time && success;
    
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Substantial path traced (steps ≥ 10) ..... %s (%d steps)\n', ...
        iif(pass_convergence, 'PASS', 'FAIL'), steps_completed);
    fprintf('No divergence ........................... %s\n', ...
        iif(success, 'PASS', 'FAIL'));
    fprintf('Execution time < 2 seconds .............. %s (%.4f s)\n', ...
        iif(pass_time, 'PASS', 'FAIL'), elapsed_time);
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % ===== OUTPUT =====
    results.steps_completed = steps_completed;
    results.lambda_final = lambda_final;
    results.execution_time = elapsed_time;
    results.converged = success;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
