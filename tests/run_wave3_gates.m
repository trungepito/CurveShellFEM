function run_wave3_gates()
% RUN_WAVE3_GATES - Verification gate for Wave 3 (Decomposition & Assembly Consolidation)
%
% This script runs all integration tests developed during Wave 3 to ensure that:
%   Task 12: Single authoritative assembly interface
%   Task 13: Extract correctorLoop from solveIncrementalStage
%   Task 14: Wire ConvergenceMonitor.recommend() to corrector
%   Task 15: SolverOptions validation and defaults audit

fprintf(['\n', repmat('=', 1, 70), '\n']);
fprintf('RUNNING WAVE 3 VERIFICATION GATES - Decomposition & Assembly\n');
fprintf([repmat('=', 1, 70), '\n']);

% Get the repository root
repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repo_root, 'src')));
addpath(genpath(fullfile(repo_root, 'tests', 'integration')));

suite = {
    'test_assembly_consolidation'
    'test_corrector_extraction'
    'test_monitor_recommendations'
    'test_solver_options_validation'
};

all_passed = true;
failed_tests = {};

fprintf('\n[Gate 12] Task 12 — Assembly Interface Consolidation\n');
fprintf('  Running %s... ', suite{1});
try
    testFunc = str2func(suite{1});
    res = feval(testFunc);
    if res.passed
        fprintf('PASSED\n');
        fprintf('    %s\n', res.details);
    else
        fprintf('FAILED\n');
        fprintf('    Details: %s\n', res.details);
        all_passed = false;
        failed_tests{end+1} = suite{1}; %#ok<AGROW>
    end
catch ME
    fprintf('CRASHED\n');
    fprintf('    Error: %s\n', ME.message);
    all_passed = false;
    failed_tests{end+1} = suite{1}; %#ok<AGROW>
end

fprintf('\n[Gate 13] Task 13 — Corrector Loop Extraction\n');
fprintf('  Running %s... ', suite{2});
try
    testFunc = str2func(suite{2});
    res = feval(testFunc);
    if res.passed
        fprintf('PASSED\n');
        fprintf('    %s\n', res.details);
    else
        fprintf('FAILED\n');
        fprintf('    Details: %s\n', res.details);
        all_passed = false;
        failed_tests{end+1} = suite{2}; %#ok<AGROW>
    end
catch ME
    fprintf('CRASHED\n');
    fprintf('    Error: %s\n', ME.message);
    all_passed = false;
    failed_tests{end+1} = suite{2}; %#ok<AGROW>
end

fprintf('\n[Gate 14] Task 14 — Monitor Recommendation Wire\n');
fprintf('  Running %s... ', suite{3});
try
    testFunc = str2func(suite{3});
    res = feval(testFunc);
    if res.passed
        fprintf('PASSED\n');
        fprintf('    %s\n', res.details);
    else
        fprintf('FAILED\n');
        fprintf('    Details: %s\n', res.details);
        all_passed = false;
        failed_tests{end+1} = suite{3}; %#ok<AGROW>
    end
catch ME
    fprintf('CRASHED\n');
    fprintf('    Error: %s\n', ME.message);
    all_passed = false;
    failed_tests{end+1} = suite{3}; %#ok<AGROW>
end

fprintf('\n[Gate 15] Task 15 — SolverOptions Validation\n');
fprintf('  Running %s... ', suite{4});
try
    testFunc = str2func(suite{4});
    res = feval(testFunc);
    if res.passed
        fprintf('PASSED\n');
        fprintf('    %s\n', res.details);
    else
        fprintf('FAILED\n');
        fprintf('    Details: %s\n', res.details);
        all_passed = false;
        failed_tests{end+1} = suite{4}; %#ok<AGROW>
    end
catch ME
    fprintf('CRASHED\n');
    fprintf('    Error: %s\n', ME.message);
    all_passed = false;
    failed_tests{end+1} = suite{4}; %#ok<AGROW>
end

fprintf(['\n', repmat('-', 1, 70), '\n']);
if all_passed
    fprintf('RESULT: ALL WAVE 3 GATES PASSED\n');
    fprintf('Wave 3 decomposition and assembly consolidation complete.\n');
    fprintf('Proceed to Wave 4 (Test Suite Implementation).\n');
else
    fprintf('RESULT: WAVE 3 GATES FAILED\n');
    fprintf('The following tests must be fixed:\n');
    for i = 1:length(failed_tests)
        fprintf('  - %s\n', failed_tests{i});
    end
    error('Wave 3 Gate Verification Failed.');
end
fprintf([repmat('-', 1, 70), '\n\n']);

end
