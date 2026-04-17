function run_wave1_gates()
% RUN_WAVE1_GATES - Verification gate for Wave 1 (P0 Correctness).
%
% This script runs all unit tests developed during Wave 1 to ensure that 
% the core numerical fixes (residual signs, monitor logic) are correct.

fprintf(['\n', repmat('=', 1, 60), '\n']);
fprintf('RUNNING WAVE 1 VERIFICATION GATES\n');
fprintf([repmat('=', 1, 60), '\n']);

% Get the repository root
repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(repo_root, 'src')));
addpath(genpath(fullfile(repo_root, 'tests', 'unit')));

suite = {
    'test_residual_sign'
    'test_convergence_monitor'
};

all_passed = true;
failed_tests = {};

for i = 1:length(suite)
    testName = suite{i};
    fprintf('[Gate 1] Running %s... ', testName);
    try
        testFunc = str2func(testName);
        res = feval(testFunc);
        if res.passed
            fprintf('PASSED\n');
        else
            fprintf('FAILED\n');
            fprintf('         Details: %s\n', res.details);
            all_passed = false;
            failed_tests{end+1} = testName; %#ok<AGROW>
        end
    catch ME
        fprintf('CRASHED\n');
        fprintf('         Error: %s\n', ME.message);
        all_passed = false;
        failed_tests{end+1} = testName; %#ok<AGROW>
    end
end

fprintf(['\n', repmat('-', 1, 60), '\n']);
if all_passed
    fprintf('RESULT: ALL WAVE 1 GATES PASSED\n');
    fprintf('Proceed to Wave 2.\n');
else
    fprintf('RESULT: WAVE 1 GATES FAILED\n');
    fprintf('The following tests must be fixed:\n');
    for i = 1:length(failed_tests)
        fprintf('  - %s\n', failed_tests{i});
    end
    error('Wave 1 Gate Verification Failed.');
end
fprintf([repmat('-', 1, 60), '\n\n']);

end
