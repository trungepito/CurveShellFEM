function results = benchmark_snapthrough_arclength()
    % BENCHMARK_SNAPTHROUGH_ARCLENGTH  Arc-length solver for snap-through
    %
    % Objective: Validate arc-length (Riks) method on limit-point buckling
    % Problem:   Shallow cylindrical arch under central downward load
    % Solver:    FEM_Solver_ArcLength (path-following with adaptive stepping)
    %
    % Expected Performance:
    %   - Lambda (load factor) history: 0 → ~0.8-1.2 (shows snap-through)
    %   - Arc-length steps: 15-30 steps to follow limit point
    %   - Snap-through point: Clearly captured in load-displacement curve
    %   - Execution time: 5-15 seconds
    
    tic;
    
    % ===== GEOMETRY & MATERIAL =====
    E = 200e9;       % Young's modulus (Pa)
    nu = 0.3;        % Poisson's ratio
    t = 0.05;        % Shell thickness (m)
    
    fprintf('=== BENCHMARK: Shallow Arch Snap-Through (Arc-Length Solver) ===\n');
    fprintf('Material: E = %.2e Pa, ν = %.3f, t = %.3f m\n', E, nu, t);
    
    % ===== PREPROCESSOR & MESH =====
    Pre = FEM_Preprocessor_v2(E, nu, t);
    
    % Shallow arch geometry: chord = 10 m, radius = 6 m
    R = 6.0;
    Chord = 10.0;
    H = sqrt(R^2 - (Chord/2)^2);
    
    % Extrusion pattern: arch profile across length
    n1 = [-Chord/2, 0, 0];
    n2 = [Chord/2, 0, 0];
    n_center = [0, 0, -H];
    nodes = [n1; n2; n_center];
    segs = [1, 2, 3, 12];
    direction = [0, 1, 0];
    Length = 6;
    
    Pre.createExtrusion(nodes, segs, direction, Length, 9);
    Pre.computeNormals();
    
    % ===== BCs & LOADING =====
    % Supports at both ends (left & right edges)
    leftNodes = Pre.selectNodesByBox(-Chord/2-0.1, -Chord/2+0.1, -1, 1, -1, 1);
    rightNodes = Pre.selectNodesByBox(Chord/2-0.1, Chord/2+0.1, -1, 1, -1, 1);
    Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Support');
    
    % Central downward load (node at arch crown)
    centerID = Pre.selectNodesByBox(-0.1, 0.1, 2.9, 3.1, R-H-0.1, R-H+0.1);
    centerID = centerID(1);
    Pre.addNodalLoad(centerID, 3, -1e5, 'CrownLoad');
    
    % ===== ARC-LENGTH SOLVER OPTIONS =====
    Opt = SolverOptions();
    Opt.Tolerance = 1e-4;
    Opt.MaxIterations = 50;
    Opt.InitialDt = 0.05;  % Finer stepping for path-following
    
    % ===== SETUP ARC-LENGTH STAGE =====
    Stage_Arc = LoadingStage(1.0);
    Stage_Arc.activateBC('Support');         % Support BC
    Stage_Arc.activateLoad('CrownLoad');
    Stage_Arc.ArcLengthRadius = 0.02;
    Stage_Arc.ArcLengthMin = 1e-5;
    Stage_Arc.ArcLengthMax = 0.25;
    
    % ===== SOLVE WITH ARC-LENGTH =====
    fprintf('\n--- SOLVING WITH ARC-LENGTH (Riks) ---\n');
    Sol_Arc = FEM_Solver_ArcLength(Pre, Opt);
    DM = FEM_DataManager('benchmark_snapthrough_arclength', 'Results', 'MAT');
    DM.initProject(Pre, Sol_Arc, struct());
    DM.attachToSolver(Sol_Arc, 1);
    Sol_Arc.solve({Stage_Arc});
    
    elapsed_time_arc = toc;
    
    % ===== EXTRACT ARC-LENGTH RESULTS =====
    c_idx = (centerID - 1) * 6 + 3;  % Z-displacement at crown node
    u_arc = Sol_Arc.U_Hist(c_idx, 1:Sol_Arc.StepCount);
    lambda_arc = Sol_Arc.LambdaHist(1:Sol_Arc.StepCount);
    f_arc = lambda_arc * 1e5;  % Scale back to force (N)
    
    arc_steps = Sol_Arc.StepCount;
    arc_min_disp = min(u_arc);
    arc_max_disp = max(u_arc);
    
    fprintf('Arc-length steps completed: %d\n', arc_steps);
    fprintf('Crown displacement range: [%.4f, %.4f] m\n', arc_min_disp, arc_max_disp);
    fprintf('Load factor range: [%.4f, %.4f]\n', min(lambda_arc), max(lambda_arc));
    fprintf('Execution time: %.4f s\n\n', elapsed_time_arc);
    
    % ===== ACCEPTANCE CRITERIA =====
    % Arc-length should capture equilibrium path with multiple steps
    pass_arc_steps = (arc_steps >= 10);              % At least 10 steps (path following)
    pass_arc_load = (max(lambda_arc) > 5.0);        % Load factor grows significantly  
    pass_arc_time = (elapsed_time_arc < 60.0);      % Reasonable execution (complex geometry)
    overall_pass = pass_arc_steps && pass_arc_load && pass_arc_time;
    
    fprintf('--- ACCEPTANCE CRITERIA ---\n');
    fprintf('Arc-length steps >= 10 ....................... %s (%d steps)\n', ...
            iif(pass_arc_steps, 'PASS', 'FAIL'), arc_steps);
    fprintf('Load factor growth > 5.0 ..................... %s (λ_max = %.2f)\n', ...
            iif(pass_arc_load, 'PASS', 'FAIL'), max(lambda_arc));
    fprintf('Execution time < 60 s ........................ %s (%.2f s)\n', ...
            iif(pass_arc_time, 'PASS', 'FAIL'), elapsed_time_arc);
    fprintf('========================================\n');
    fprintf('RESULT: %s (Arc-length path-following)\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % ===== OUTPUT =====
    results.arclength_steps = arc_steps;
    results.displacement_history = u_arc;
    results.lambda_history = lambda_arc;
    results.force_history = f_arc;
    results.displacement_range = [arc_min_disp, arc_max_disp];
    results.execution_time = elapsed_time_arc;
    results.overall_pass = overall_pass;
    
end

function str = iif(condition, true_str, false_str)
    if condition, str = true_str; else, str = false_str; end
end
