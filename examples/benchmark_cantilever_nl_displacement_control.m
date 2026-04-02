function results = benchmark_cantilever_nl_displacement_control()
    % BENCHMARK_CANTILEVER_NL_DISPLACEMENT_CONTROL   Nonlinear path-following
    %
    % Objective: Validate adaptive nonlinear solver with geometric nonlinearity
    % Problem:   Cantilever beam with large displacement
    % Solver:    FEM_Solver_Adaptive (displacement-control)
    %
    % Expected Performance:
    %   - Displacement: Multiple steps showing nonlinear behavior
    %   - Convergence: Newton-Raphson with adaptive stepping
    %   - Execution time: 2-8 seconds
    
    tic;
    
    % ===== GEOMETRY & MATERIAL =====
    E = 210e9;       % Young's modulus (Pa)
    nu = 0.3;        % Poisson's ratio
    t = 0.01;        % Shell thickness (m)
    L = 1.0;         % Length (m)
    W = 0.1;         % Width (m)
    u_prescribed = 0.3;  % Final prescribed displacement (m)
    
    fprintf('=== BENCHMARK: Cantilever Nonlinear (Displacement Control) ===\n');
    fprintf('Material: E = %.2e Pa, ν = %.3f\n', E, nu);
    fprintf('Geometry: L = %.3f m, W = %.3f m, t = %.4f m\n', L, W, t);
    fprintf('Loading: Displacement control to %.2f m\n\n', u_prescribed);
    
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
    Pre.addBC(tipNode, 2, u_prescribed, 'TipDisp');
    
    % ===== SOLVER OPTIONS =====
    Opt = SolverOptions();
    Opt.Tolerance = 1e-4;
    Opt.MaxIterations = 50;
    Opt.InitialDt = 0.1;
    
    % ===== SETUP LOADING STAGE =====
    Stage = LoadingStage(1.0);  % 1.0 second duration
    Stage.activateBC('Fixed');         % Fixed BC  
    Stage.activateBC('TipDisp');       % Prescribed displacement BC
    
    % ===== SOLVE =====
    fprintf('--- SOLVING (Nonlinear Displacement Control) ---\n');
    Sol = FEM_Solver_Adaptive(Pre, Opt);
    Sol.solve({Stage});
    
    elapsed_time = toc;
    
    % ===== EXTRACT RESULTS =====
    u_hist = Sol.U_Hist((tipNode - 1) * 6 + 2, 1:Sol.StepCount);
    u_final = u_hist(end);
    times = Sol.History_Time;
    steps_completed = Sol.StepCount;
    
    fprintf('Steps completed: %d\n', steps_completed);
    fprintf('Final displacement: %.6e m (prescribed: %.2f m)\n', u_final, u_prescribed);
    fprintf('Execution time: %.4f s\n\n', elapsed_time);
    
    % ===== ACCEPTANCE =====
    error_percent = abs(u_final - u_prescribed) / u_prescribed * 100;
    pass_displacement = (error_percent < 5.0);  % 5% tolerance on prescribed displacement
    pass_steps = (steps_completed >= 2);        % At least 2 steps (nonlinear behavior)
    pass_time = (elapsed_time < 15.0);
    overall_pass = pass_displacement && pass_steps && pass_time;
    
    fprintf('--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Displacement within 5%% of prescribed ... %s (%.4f vs %.2f m, error: %.3f%%)\n', ...
            iif(pass_displacement, 'PASS', 'FAIL'), u_final, u_prescribed, error_percent);
    fprintf('Multiple load steps (>= 2) ............. %s (%d steps)\n', ...
            iif(pass_steps, 'PASS', 'FAIL'), steps_completed);
    fprintf('Execution time < 15 s .................. %s (%.4f s)\n', ...
            iif(pass_time, 'PASS', 'FAIL'), elapsed_time);
    fprintf('========================================\n');
    fprintf('RESULT: %s (Nonlinear displacement control)\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % ===== OUTPUT =====
    results.displacement_final = u_final;
    results.displacement_prescribed = u_prescribed;
    results.displacement_error_percent = error_percent;
    results.displacement_history = u_hist;
    results.time_history = times;
    results.steps_completed = steps_completed;
    results.execution_time = elapsed_time;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end

% function str = iif(condition, true_str, false_str)
%     if condition
%         str = true_str;
%     else
%         str = false_str;
%     end
% end