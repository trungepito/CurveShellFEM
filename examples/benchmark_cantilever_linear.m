function results = benchmark_cantilever_linear()
    % BENCHMARK_CANTILEVER_LINEAR   Linear FEM solver validation 
    %
    % Objective: Validate displacement using analytical cantilever theory
    % Problem:   Cantilever beam, point load at free end
    % Reference: Euler-Bernoulli theory
    % Solver:    FEM_Solver (linear static)
    
    tic;
    
    % ===== GEOMETRY & MATERIAL =====
    E = 210e9;       % Young's modulus (Pa)
    nu = 0.3;        % Poisson's ratio
    t = 0.01;        % Shell thickness (m)
    L = 1.0;         % Length (m)
    W = 0.01;        % Width (m) - make narrow like a beam
    P = 1000;        % Point load (N)
    
    % Analytical: Euler-Bernoulli cantilever
    % For a shell plate: I = W * t³ / 12  (bending about Y-axis)
    I = (W * t^3) / 12;
    delta_analytical = (P * L^3) / (3 * E * I);
    
    fprintf('=== BENCHMARK: Cantilever Linear ===\n');
    fprintf('Material: E = %.2e Pa, ν = %.3f\n', E, nu);
    fprintf('Geometry: L = %.3f m, W = %.3f m, t = %.4f m (beam-like shell)\n', L, W, t);
    fprintf('Load: P = %.1f N (1000 N)\n', P);
    fprintf('I = W*t³/12 = %.3e m⁴\n', I);
    fprintf('Analytical deflection: %.6e m\n\n', delta_analytical);
    
    % ===== PREPROCESSOR & MESH =====
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0, 0, 0], L, W);
    Pre.meshAllPatches(10, 2);
    Pre.computeNormals();
    
    % ===== BCs & LOADING =====
    fixedNodes = Pre.selectNodesByBox(-0.01, 0.01, -1, 1, -1, 1);
    Pre.addBC(fixedNodes, 1:6, 0, 'Fixed');
    
    tipNodes = Pre.selectNodesByBox(L-0.01, L+0.01, W/2-0.05, W/2+0.05, -1, 1);
    tipNode = tipNodes(1);
    Pre.addNodalLoad(tipNode, 2, P, 'TipLoad');
    
    % ===== SOLVE (Linear Static) =====
    fprintf('--- SOLVING (Linear Static) ---\n');
    Sol = FEM_Solver(Pre);
    Sol.solveStatic();
    
    % ===== EXTRACT RESULT =====
    u_FEM = Sol.U((tipNode - 1) * 6 + 2);  % Y-displacement
    error_percent = abs(u_FEM - delta_analytical) / abs(delta_analytical) * 100;
    
    elapsed_time = toc;
    fprintf('FEM displacement:  %.6e m\n', u_FEM);
    fprintf('Analytical:        %.6e m\n', delta_analytical);
    fprintf('Error vs theory:   %.3f %%\n', error_percent);
    fprintf('Time: %.4f s\n\n', elapsed_time);
    
    % ===== ACCEPTANCE =====
    pass = (error_percent < 1.0);  % Allow 1% tolerance
    fprintf('--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Displacement error < 1.0%% ... %s (error: %.3f%%)\n', iif(pass, 'PASS', 'FAIL'), error_percent);
    fprintf('========================================\n');
    fprintf('RESULT: %s (Linear solver validation)\n', iif(pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % ===== OUTPUT =====
    results.displacement_FEM = u_FEM;
    results.displacement_analytical = delta_analytical;
    results.error_percent = error_percent;
    results.execution_time = elapsed_time;
    results.overall_pass = pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end

