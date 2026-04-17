function run_wave2_gates()
% RUN_WAVE2_GATES - Verification gate for Wave 2 (Data Manager Embedding).
%
% This script runs all integration tests developed during Wave 2 to ensure that:
%   Task 8: O(1) matfile append is functioning correctly
%   Task 9: DataManager listener is properly decoupled from Solver
%   Task 10: FEM_Postprocessor_v2 can operate from snapshot only
%   Task 11: Archive fallback warnings are suppressible and informative

fprintf(['\n', repmat('=', 1, 70), '\n']);
fprintf('RUNNING WAVE 2 VERIFICATION GATES - Data Manager Embedding\n');
fprintf([repmat('=', 1, 70), '\n']);

% Get the repository root
repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repo_root, 'src')));
addpath(genpath(fullfile(repo_root, 'tests', 'integration')));

suite = {
    'test_data_manager_io'
    'test_data_manager_listener'
    'test_postprocessor_snapshot'
    'test_archive_fallback_new'
};

all_passed = true;
failed_tests = {};

fprintf('\n[Gate 8] Task 8 — O(1) matfile append\n');
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

fprintf('\n[Gate 9] Task 9 — Listener Decoupling\n');
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

fprintf('\n[Gate 10] Task 10 — Snapshot-Only Postprocessor\n');
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

fprintf('\n[Gate 11] Task 11 — Archive Fallback Warning\n');
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
    fprintf('RESULT: ALL WAVE 2 GATES PASSED\n');
    fprintf('Data Manager embedding complete. Proceed to Wave 3.\n');
else
    fprintf('RESULT: WAVE 2 GATES FAILED\n');
    fprintf('The following tests must be fixed:\n');
    for i = 1:length(failed_tests)
        fprintf('  - %s\n', failed_tests{i});
    end
    error('Wave 2 Gate Verification Failed.');
end
fprintf([repmat('-', 1, 70), '\n\n']);

end
