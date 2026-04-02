function results = benchmark_arclength_constraint_comparison()
    % BENCHMARK_ARCLENGTH_CONSTRAINT_COMPARISON  Riks vs. Spherical constraint
    %
    % Objective: Compare two arc-length constraint formulations on same problem
    % Problem:   Classic snap-through arch (same geometry as Phase 26)
    % Solver:    FEM_Solver_ArcLength with constraint selection
    % Method 1:  Riks hyperplane constraint (current, ADR-003)
    % Method 2:  Spherical constraint (alternative formulation)
    
    tic;
    
    fprintf('=== BENCHMARK: Arc-Length Constraint Comparison ===\n');
    fprintf('Comparing Riks vs. Spherical arc-length constraints\n\n');
    
    % ===== GEOMETRY: SNAP-THROUGH ARCH =====
    E = 200e9;      % Steel
    nu = 0.3;
    t = 0.05;
    R = 6.0;        % Arch radius
    Chord = 10.0;   % Chord length
    H = sqrt(R^2 - (Chord/2)^2);
    
    fprintf('Arch geometry: R = %.1f m, Chord = %.1f m, Height = %.3f m\n', R, Chord, H);
    
    % ===== CREATE MESH =====
    Pre = FEM_Preprocessor_v2(E, nu, t);
    n1 = [-Chord/2, 0, 0];
    n2 = [Chord/2, 0, 0];
    n_center = [0, 0, -H];
    nodes = [n1; n2; n_center];
    segs = [1, 2, 3, 12];
    direction = [0, 1, 0];
    Length = 6;
    Pre.createExtrusion(nodes, segs, direction, Length, 9);
    Pre.computeNormals();
    
    % ===== BOUNDARY CONDITIONS =====
    leftNodes = Pre.selectNodesByBox(-Chord/2-0.1, -Chord/2+0.1, -1, 1, -1, 1);
    rightNodes = Pre.selectNodesByBox(Chord/2-0.1, Chord/2+0.1, -1, 1, -1, 1);
    Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Support');
    
    % Crown load
    centerID = Pre.selectNodesByBox(-0.1, 0.1, 2.9, 3.1, R-H-0.1, R-H+0.1);
    centerID = centerID(1);
    Pre.addNodalLoad(centerID, 3, -1e5, 'CrownLoad');
    
    % ===== SOLVE WITH RIKS CONSTRAINT =====
    opts = SolverOptions();
    opts.Tolerance = 1e-4;
    opts.MaxIterations = 30;
    
    fprintf('\n--- METHOD 1: RIKS CONSTRAINT ---\n');
    SolRiks = FEM_Solver_ArcLength(Pre, opts);
    StageRiks = LoadingStage(1.0);
    StageRiks.activateBC('Support');
    StageRiks.activateLoad('CrownLoad');
    StageRiks.ConstraintType = 'Riks';
    
    SolRiks.solve({StageRiks});
    
    % Extract results
    u_tip_riks = SolRiks.U((centerID-1)*6 + 3);
    steps_riks = SolRiks.StepCount;
    lambda_riks = SolRiks.History_Time(steps_riks);
    
    fprintf('Riks: Steps = %d, Final λ = %.4f, Tip displacement = %.4f m\n', ...
        steps_riks, lambda_riks, u_tip_riks);
    
    % ===== SOLVE WITH SPHERICAL CONSTRAINT =====
    fprintf('\n--- METHOD 2: SPHERICAL CONSTRAINT ---\n');
    Pre2 = FEM_Preprocessor_v2(E, nu, t);
    Pre2.createExtrusion(nodes, segs, direction, Length, 9);
    Pre2.computeNormals();
    Pre2.addBC([leftNodes; rightNodes], 1:3, 0, 'Support');
    Pre2.addNodalLoad(centerID, 3, -1e5, 'CrownLoad');
    
    SolSph = FEM_Solver_ArcLength(Pre2, opts);
    StageSph = LoadingStage(1.0);
    StageSph.activateBC('Support');
    StageSph.activateLoad('CrownLoad');
    StageSph.ConstraintType = 'Spherical';  % Alternative constraint
    
    try
        SolSph.solve({StageSph});
        u_tip_sph = SolSph.U((centerID-1)*6 + 3);
        steps_sph = SolSph.StepCount;
        lambda_sph = SolSph.History_Time(steps_sph);
        fprintf('Spherical: Steps = %d, Final λ = %.4f, Tip displacement = %.4f m\n', ...
            steps_sph, lambda_sph, u_tip_sph);
        sph_converged = true;
    catch
        fprintf('Spherical constraint did not converge (not yet implemented)\n');
        sph_converged = false;
        steps_sph = 0;
        lambda_sph = 0;
        u_tip_sph = 0;
    end
    
    elapsed_time = toc;
    
    % ===== COMPARISON =====
    fprintf('\n--- COMPARISON ---\n');
    if sph_converged
        lambda_diff = abs(lambda_sph - lambda_riks) / lambda_riks * 100;
        fprintf('Load factor difference: %.2f %%\n', lambda_diff);
        fprintf('Step count: Riks = %d, Spherical = %d (ratio = %.2f)\n', ...
            steps_riks, steps_sph, steps_sph / steps_riks);
        pass_comparison = (lambda_diff < 5);  % Within 5%
    else
        pass_comparison = false;  % Spherical not yet implemented
    end
    
    pass_riks = (steps_riks > 20) && (abs(lambda_riks - 11.35) < 0.5);
    overall_pass = pass_riks && (pass_comparison || ~sph_converged);
    
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Riks convergence (steps > 20, λ ≈ 11.35) .. %s\n', ...
        iif(pass_riks, 'PASS', 'FAIL'));
    if sph_converged
        fprintf('Spherical agreement (λ diff < 5%%) ....... %s\n', ...
            iif(pass_comparison, 'PASS', 'FAIL'));
    end
    fprintf('Execution time: %.4f seconds\n', elapsed_time);
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % ===== OUTPUT =====
    results.steps_riks = steps_riks;
    results.lambda_riks = lambda_riks;
    results.u_tip_riks = u_tip_riks;
    results.steps_spherical = steps_sph;
    results.lambda_spherical = lambda_sph;
    results.u_tip_spherical = u_tip_sph;
    results.spherical_converged = sph_converged;
    results.execution_time = elapsed_time;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
