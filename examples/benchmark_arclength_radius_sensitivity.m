function results = benchmark_arclength_radius_sensitivity()
    % BENCHMARK_ARCLENGTH_RADIUS_SENSITIVITY  Arc-length step size study
    %
    % Objective: Study effect of arc-length radius on convergence
    % Problem:   Snap-through (same as constraint comparison)
    % Variations: Test 4 different radius values
    
    tic;
    fprintf('=== BENCHMARK: Arc-Length Radius Sensitivity ===\n');
    fprintf('Study effect of arc-length step size on convergence\n\n');
    
    % Problem setup (same as other arc-length benchmarks)
    E = 200e9;
    nu = 0.3;
    t = 0.05;
    R = 6.0;
    Chord = 10.0;
    H = sqrt(R^2 - (Chord/2)^2);
    
    % Test different radius values
    radii = [0.01, 0.05, 0.10, 0.25];
    names = {'Small (0.01)', 'Medium (0.05)', 'Large (0.10)', 'Very Large (0.25)'};
    
    fprintf('Testing %d arc-length radius values on snap-through problem:\n\n', length(radii));
    
    results_all = [];
    
    for r_idx = 1:length(radii)
        radius = radii(r_idx);
        name = names{r_idx};
        
        fprintf('Test %d: %s\n', r_idx, name);
        
        % Create preprocessor
        Pre = FEM_Preprocessor_v2(E, nu, t);
        n1 = [-Chord/2, 0, 0];
        n2 = [Chord/2, 0, 0];
        n_center = [0, 0, -H];
        nodes = [n1; n2; n_center];
        segs = [1, 2, 3, 12];
        Pre.createExtrusion(nodes, segs, [0, 1, 0], 6, 9);
        Pre.computeNormals();
        
        % BCs
        leftNodes = Pre.selectNodesByBox(-Chord/2-0.1, -Chord/2+0.1, -1, 1, -1, 1);
        rightNodes = Pre.selectNodesByBox(Chord/2-0.1, Chord/2+0.1, -1, 1, -1, 1);
        Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Support');
        
        centerID = Pre.selectNodesByBox(-0.1, 0.1, 2.9, 3.1, R-H-0.1, R-H+0.1);
        centerID = centerID(1);
        Pre.addNodalLoad(centerID, 3, -1e5, 'CrownLoad');
        
        % Solve with specific radius
        opts = SolverOptions();
        opts.Tolerance = 1e-4;
        opts.MaxIterations = 30;
        % Note: ArcLengthRadius is set on LoadingStage, not SolverOptions
        
        try
            Sol = FEM_Solver_ArcLength(Pre, opts);
            Stage = LoadingStage(1.0);
            Stage.activateBC('Support');
            Stage.activateLoad('CrownLoad');
            Stage.ConstraintType = 'Riks';
            Stage.ArcLengthRadius = radius;
            
            Sol.solve({Stage});
            
            steps = Sol.StepCount;
            lambda = Sol.History_Time(steps);
            success = true;
        catch
            steps = 0;
            lambda = 0;
            success = false;
        end
        
        fprintf('  Steps: %3d, λ_final: %.4f, Status: %s\n', ...
            steps, lambda, iif(success, 'OK', 'FAILED'));
        
        results_all = [results_all; struct('radius', radius, 'steps', steps, 'lambda', lambda, 'success', success)];
    end
    
    elapsed_time = toc;
    
    % ===== ANALYSIS =====
    fprintf('\n--- RADIUS SENSITIVITY ANALYSIS ---\n');
    fprintf('Radius  | Steps | λ_final | Expected Trend\n');
    fprintf('--------|-------|---------|--------------------\n');
    for i = 1:length(radii)
        exp_trend = ['should=' iif(i==1, 'many', iif(i==2, 'optimal', iif(i==3, 'fewer', 'few')))];
        fprintf('%s | %5d | %7.4f | %s\n', ...
            names{i}(1:11), results_all(i).steps, results_all(i).lambda, exp_trend);
    end
    
    % Check trend: small radius→many steps, medium→fewer, large→fewest
    trendOK = (results_all(1).steps > results_all(2).steps) && ...
              (results_all(2).steps > results_all(3).steps);
    
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Step count trend (decreasing with radius) %s\n', ...
        iif(trendOK, 'PASS', 'FAIL'));
    fprintf('All λ_final values within 1%% ............ %s\n', ...
        iif(max(abs([results_all.lambda] - results_all(2).lambda))/results_all(2).lambda < 0.01, 'PASS', 'FAIL'));
    fprintf('Execution time: %.4f seconds\n', elapsed_time);
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(trendOK, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % Store results
    results.radii = radii;
    results.steps_per_radius = [results_all.steps];
    results.lambda_per_radius = [results_all.lambda];
    results.execution_time = elapsed_time;
    results.trend_ok = trendOK;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
