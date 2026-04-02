function results = benchmark_postbuckling_instability()
    % BENCHMARK_POSTBUCKLING_INSTABILITY  Instability handling in post-limit region
    %
    % Objective: Validate arc-length navigation through unstable region
    % Problem:   Plate in post-buckling (beyond critical load)
    % Physics:   Negative stiffness / bifurcation point
    
    tic;
    fprintf('=== BENCHMARK: Post-Buckling Instability ===\n');
    fprintf('Validate arc-length through negative stiffness region\n\n');
    
    E = 200e9;
    nu = 0.3;
    t = 0.01;
    L = 1.0;
    W = 0.5;
    
    fprintf('Geometry: L=%.1f m, W=%.1f m, t=%.4f m\n', L, W, t);
    
    % Create mesh
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0, 0, 0], L, W);
    Pre.meshAllPatches(10, 5);
    Pre.computeNormals();
    
    % Simply supported edges
    perimeter = Pre.selectNodesByBox(-0.1, 1.1, -0.1, 0.6, -0.1, 0.1);
    Pre.addBC(perimeter, 3, 0, 'SimpleSup');  % z-disp fixed
    
    % Center load
    center = Pre.selectNodesByBox(L/2-0.1, L/2+0.1, W/2-0.1, W/2+0.1, -0.1, 0.1);
    if ~isempty(center)
        Pre.addNodalLoad(center(1), 3, -1e5, 'CenterLoad');
    end
    
    % Solve
    opts = SolverOptions();
    opts.Tolerance = 1e-3;
    opts.MaxIterations = 20;
    
    fprintf('\n--- SOLVER EXECUTION ---\n');
    try
        Sol = FEM_Solver_ArcLength(Pre, opts);
        Stage = LoadingStage(2.0);  % Push well into post-buckling
        Stage.activateBC('SimpleSup');
        Stage.activateLoad('CenterLoad');
        Stage.ConstraintType = 'Riks';
        
        Sol.solve({Stage});
        
        steps = Sol.StepCount;
        lambda = Sol.History_Time(steps);
        success = true;
    catch ME
        fprintf('Error: %s\n', ME.message);
        steps = 0;
        lambda = 0;
        success = false;
    end
    
    elapsed_time = toc;
    
    fprintf('Steps: %d, λ: %.4f\n', steps, lambda);
    fprintf('Time: %.4f seconds\n', elapsed_time);
    
    % ===== ACCEPTANCE CRITERIA =====
    pass_convergence = (steps > 5) && success;
    pass_time = (elapsed_time < 1.5);
    overall_pass = pass_convergence && pass_time;
    
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Navigated instability (steps > 5) ...... %s (%d steps)\n', ...
        iif(pass_convergence, 'PASS', 'FAIL'), steps);
    fprintf('Execution time < 1.5 seconds ........... %s (%.4f s)\n', ...
        iif(pass_time, 'PASS', 'FAIL'), elapsed_time);
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % Output
    results.steps = steps;
    results.lambda_final = lambda;
    results.execution_time = elapsed_time;
    results.converged = success;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
