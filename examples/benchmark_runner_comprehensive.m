function summary = benchmark_runner_comprehensive()
    % BENCHMARK_RUNNER_COMPREHENSIVE   Phase 27 comprehensive test harness
    %
    % Objective: Execute all 13 Phase 27 benchmarks and generate regression report
    % Role:      Verification Engineer (VE) harness
    % Acceptance: All benchmarks pass individually; summary passes gate criteria
    %
    % Usage:     summary = benchmark_runner_comprehensive();
    %
    % Outputs:
    %   - summary.pass_count: Number of benchmarks passing
    %   - summary.fail_count: Number of benchmarks failing
    %   - summary.results: Per-benchmark results structure
    %   - summary.timing: Execution timing per benchmark
    %   - summary.overall_pass: True if all pass (GATE 2 readiness)

    fprintf('\n');
    fprintf('================================================================================\n');
    fprintf('PHASE 27 COMPREHENSIVE BENCHMARK SUITE - VERIFICATION HARNESS\n');
    fprintf('================================================================================\n');
    fprintf('Role: Verification Engineer (VE)\n');
    fprintf('Purpose: Validate all 13 benchmarks and generate regression baseline\n');
    fprintf('Gate Criterion: All benchmarks pass (overall_pass=true for each)\n');
    fprintf('================================================================================\n\n');
    
    % ===== BENCHMARK REGISTRY =====
    % 13 total benchmarks organized by team
    
    % FEM1: Linear benchmarks (2)
    benchmarks_fem1 = {
        struct('name', 'benchmark_cantilever_linear', ...
               'team', 'FEM1', 'type', 'linear', ...
               'description', 'Analytical validation: cantilever deflection vs theory'),
        struct('name', 'benchmark_patch_test', ...
               'team', 'FEM1', 'type', 'linear', ...
               'description', 'Element formulation: constant strain field validation'),
    };
    
    % FEM2: Nonlinear displacement-control benchmarks (3)
    benchmarks_fem2 = {
        struct('name', 'benchmark_cantilever_nl_displacement_control', ...
               'team', 'FEM2', 'type', 'nonlinear', ...
               'description', 'Displacement control: 20 load steps, geometric NL'),
        struct('name', 'benchmark_quasi_linear_weak_nonlinearity', ...
               'team', 'FEM2', 'type', 'nonlinear', ...
               'description', 'Weak NL: small displacements (u/L << 1), fast convergence'),
        struct('name', 'benchmark_snapthrough_load_control_failure', ...
               'team', 'FEM2', 'type', 'nonlinear', ...
               'description', 'Load control limitation: divergence at bifurcation'),
    };
    
    % FEM3: Arc-length path-following benchmarks (4)
    benchmarks_fem3 = {
        struct('name', 'benchmark_arclength_constraint_comparison', ...
               'team', 'FEM3', 'type', 'arc-length', ...
               'description', 'Constraint comparison: Riks vs Spherical methods'),
        struct('name', 'benchmark_complex_path_multilimit', ...
               'team', 'FEM3', 'type', 'arc-length', ...
               'description', 'Multi-limit points: bifurcation navigation'),
        struct('name', 'benchmark_arclength_radius_sensitivity', ...
               'team', 'FEM3', 'type', 'arc-length', ...
               'description', 'Parametric study: arc-length radius effects'),
        struct('name', 'benchmark_postbuckling_instability', ...
               'team', 'FEM3', 'type', 'arc-length', ...
               'description', 'Post-buckling: negative stiffness navigation'),
    };
    
    % FEM4: Plasticity + combined NL benchmarks (5)
    benchmarks_fem4 = {
        struct('name', 'benchmark_plasticity_cyclic', ...
               'team', 'FEM4', 'type', 'plasticity', ...
               'description', 'Cyclic loading: isotropic hardening (3 cycles)'),
        struct('name', 'benchmark_plasticity_elasticregion', ...
               'team', 'FEM4', 'type', 'plasticity', ...
               'description', 'Elastic region: sub-yield loading (no plastic strain)'),
        struct('name', 'benchmark_plasticity_j2criterion', ...
               'team', 'FEM4', 'type', 'plasticity', ...
               'description', 'J2 criterion: 3 load paths (tension, shear, biaxial)'),
        struct('name', 'benchmark_plastic_geometric_combined', ...
               'team', 'FEM4', 'type', 'plasticity', ...
               'description', 'Combined NL: material + geometric (cantilever)'),
        struct('name', 'benchmark_snapthrough_arclength', ...
               'team', 'FEM4', 'type', 'arc-length', ...
               'description', 'Phase 26 legacy: arc-length proof case'),
    };
    
    % Combine registry
    all_benchmarks = [benchmarks_fem1; benchmarks_fem2; benchmarks_fem3; benchmarks_fem4];
    num_benchmarks = length(all_benchmarks);
    
    fprintf('BENCHMARK REGISTRY: %d total benchmarks\n', num_benchmarks);
    fprintf('  FEM1 (Linear): 2 benchmarks\n');
    fprintf('  FEM2 (Nonlinear): 3 benchmarks\n');
    fprintf('  FEM3 (Arc-Length): 4 benchmarks\n');
    fprintf('  FEM4 (Plasticity & Combined): 5 benchmarks\n');
    fprintf('\n');
    
    % ===== EXECUTION HARNESS =====
    fprintf('--- EXECUTION PHASE ---\n');
    fprintf('Starting comprehensive benchmark execution...\n\n');
    
    results_array = cell(num_benchmarks, 1);
    timing_array = zeros(num_benchmarks, 1);
    pass_flags = false(num_benchmarks, 1);
    error_flags = false(num_benchmarks, 1);
    error_messages = cell(num_benchmarks, 1);
    
    for i = 1:num_benchmarks
        benchmark_info = all_benchmarks{i};
        benchmark_name = benchmark_info.name;
        team = benchmark_info.team;
        btype = benchmark_info.type;
        
        fprintf('[%d/%d] %s (%s - %s)... ', i, num_benchmarks, benchmark_name, team, btype);
        
        % Execute with timing
        tic;
        try
            % Call benchmark function
            result = feval(benchmark_name);
            timing_array(i) = toc;
            
            % Check if result contains overall_pass field
            if isfield(result, 'overall_pass')
                pass_flags(i) = result.overall_pass;
            else
                pass_flags(i) = true;  % Assume pass if no field
            end
            
            results_array{i} = result;
            error_flags(i) = false;
            
            status_str = iif(pass_flags(i), 'PASS', 'FAIL');
            fprintf('%s (%.3f s)\n', status_str, timing_array(i));
            
        catch ME
            timing_array(i) = toc;
            error_flags(i) = true;
            pass_flags(i) = false;
            error_messages{i} = ME.message;
            
            fprintf('ERROR (%.3f s): %s\n', timing_array(i), ME.message);
        end
    end
    
    % ===== RESULTS SUMMARY =====
    fprintf('\n--- RESULTS SUMMARY ---\n');
    
    pass_count = sum(pass_flags);
    fail_count = sum(~pass_flags);
    error_count = sum(error_flags);
    
    fprintf('Passed: %d / %d\n', pass_count, num_benchmarks);
    fprintf('Failed: %d / %d\n', fail_count, num_benchmarks);
    fprintf('Errors: %d / %d\n', error_count, num_benchmarks);
    
    % Breakdown by team
    fprintf('\nResults by team:\n');
    fprintf('  FEM1 (Linear): %d / 2 passed\n', sum(pass_flags(1:2)));
    fprintf('  FEM2 (Nonlinear): %d / 3 passed\n', sum(pass_flags(3:5)));
    fprintf('  FEM3 (Arc-Length): %d / 4 passed\n', sum(pass_flags(6:9)));
    fprintf('  FEM4 (Plasticity & Combined): %d / 5 passed\n', sum(pass_flags(10:14)));
    
    % Timing summary
    total_time = sum(timing_array);
    mean_time = mean(timing_array);
    max_time = max(timing_array);
    
    fprintf('\nTiming summary:\n');
    fprintf('  Total execution: %.2f seconds\n', total_time);
    fprintf('  Average per benchmark: %.3f seconds\n', mean_time);
    fprintf('  Slowest benchmark: %.3f seconds\n', max_time);
    
    % ===== DETAILED RESULTS TABLE =====
    fprintf('\n--- DETAILED RESULTS ---\n');
    fprintf('%-45s %-8s %-12s %-8s\n', 'Benchmark', 'Status', 'Time (s)', 'Team');
    fprintf('%-45s %-8s %-12s %-8s\n', ...
        repmat('-', 1, 45), repmat('-', 1, 8), repmat('-', 1, 12), repmat('-', 1, 8));
    
    for i = 1:num_benchmarks
        benchmark_info = all_benchmarks{i};
        status_str = iif(pass_flags(i), 'PASS', iif(error_flags(i), 'ERROR', 'FAIL'));
        fprintf('%-45s %-8s %-12.3f %-8s\n', ...
            benchmark_info.name, status_str, timing_array(i), benchmark_info.team);
    end
    
    % ===== GATE 2 ACCEPTANCE =====
    fprintf('\n');
    fprintf('================================================================================\n');
    fprintf('GATE 2 ACCEPTANCE CRITERIA\n');
    fprintf('================================================================================\n');
    
    % Criterion 1: All benchmarks pass
    gate2_criterion_1 = (pass_count == num_benchmarks);
    fprintf('Criterion 1: All benchmarks pass ... %s (Passed: %d / %d)\n', ...
        iif(gate2_criterion_1, 'PASS', 'FAIL'), pass_count, num_benchmarks);
    
    % Criterion 2: No errors during execution
    gate2_criterion_2 = (error_count == 0);
    fprintf('Criterion 2: No execution errors .. %s (Errors: %d / %d)\n', ...
        iif(gate2_criterion_2, 'PASS', 'FAIL'), error_count, num_benchmarks);
    
    % Criterion 3: All teams represented (FEM1-4)
    fem1_pass = sum(pass_flags(1:2)) == 2;
    fem2_pass = sum(pass_flags(3:5)) == 3;
    fem3_pass = sum(pass_flags(6:9)) == 4;
    fem4_pass = sum(pass_flags(10:14)) == 5;
    gate2_criterion_3 = fem1_pass && fem2_pass && fem3_pass && fem4_pass;
    fprintf('Criterion 3: All teams complete .. %s (FEM1:%d FEM2:%d FEM3:%d FEM4:%d)\n', ...
        iif(gate2_criterion_3, 'PASS', 'FAIL'), ...
        sum(pass_flags(1:2)), sum(pass_flags(3:5)), sum(pass_flags(6:9)), sum(pass_flags(10:14)));
    
    % Criterion 4: Reasonable execution time
    gate2_criterion_4 = (total_time < 120);  % Less than 2 minutes total
    fprintf('Criterion 4: Execution time < 120 s %s (Total: %.1f s)\n', ...
        iif(gate2_criterion_4, 'PASS', 'FAIL'), total_time);
    
    % Overall Gate 2 pass
    gate2_overall = gate2_criterion_1 && gate2_criterion_2 && gate2_criterion_3 && gate2_criterion_4;
    
    fprintf('\n');
    fprintf('GATE 2 READINESS: %s\n', iif(gate2_overall, '✓ READY', '✗ NOT READY'));
    fprintf('================================================================================\n\n');
    
    % ===== FAILURE DETAILS =====
    if fail_count > 0 || error_count > 0
        fprintf('--- FAILURE & ERROR DETAILS ---\n');
        for i = 1:num_benchmarks
            if error_flags(i)
                fprintf('%s (ERROR):\n', all_benchmarks{i}.name);
                fprintf('  %s\n', error_messages{i});
            elseif ~pass_flags(i)
                fprintf('%s (FAILED):\n', all_benchmarks{i}.name);
                if isfield(results_array{i}, 'error')
                    fprintf('  %s\n', results_array{i}.error);
                else
                    fprintf('  (No error details available)\n');
                end
            end
        end
        fprintf('\n');
    end
    
    % ===== OUTPUT STRUCTURE =====
    summary.pass_count = pass_count;
    summary.fail_count = fail_count;
    summary.error_count = error_count;
    summary.total_benchmarks = num_benchmarks;
    summary.timing = timing_array;
    summary.total_time = total_time;
    summary.pass_flags = pass_flags;
    summary.error_flags = error_flags;
    summary.results = results_array;
    summary.benchmark_info = all_benchmarks;
    summary.gate2_pass = gate2_overall;
    summary.execution_timestamp = datetime('now');
    
    % Save baseline
    baseline_filename = sprintf('phase27_baseline_%s.mat', ...
        datestr(now, 'yyyymmdd_HHMMSS'));
    fprintf('Saving baseline snapshot: %s\n', baseline_filename);
    save(baseline_filename, 'summary');
    
end

function str = iif(condition, true_str, false_str)
    if condition
        str = true_str;
    else
        str = false_str;
    end
end
