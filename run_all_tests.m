% run_all_tests.m
% Continuous Integration Runner for CurveShellFEM

try
    % 1. Setup Search Path
    fprintf('\n--- INITIALIZING PATH ---\n');
    addpath(genpath('src'));
    addpath(genpath('tests'));
    
    % 2. Run Unit Tests
    fprintf('\n--- RUNNING UNIT TESTS ---\n');
    results_unit = runtests('tests/unit');
    disp(table(results_unit));
    
    % 3. Run Patch Tests
    fprintf('\n--- RUNNING PATCH TESTS ---\n');
    results_patch = runtests('tests/Patchtest');
    disp(table(results_patch));
    
    % 4. Summary & Exit
    all_results = [results_unit, results_patch];
    num_failed = sum([all_results.Failed]);
    
    if num_failed == 0
        fprintf('\n[ALL TESTS PASSED]\n');
        exit(0);
    else
        fprintf('\n[TESTS FAILED: %d]\n', num_failed);
        exit(1);
    end

catch ME
    fprintf('\n[FATAL ERROR during test execution]\n');
    disp(ME.message);
    exit(1);
end
