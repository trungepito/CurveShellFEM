function result = run_subtest(result, name, fn)
% RUN_SUBTEST  Run fn() and record pass/fail in result.subtests.
% fn must throw on failure (e.g. use assert_equal or built-in assert).
%
% Usage:
%   result = run_subtest(result, 'UT1.1 symmetry', @() assert_equal(K, K', 1e-10));
try
    fn();
    entry = struct('name', name, 'passed', true, 'msg', 'ok');
catch ME
    entry = struct('name', name, 'passed', false, 'msg', ME.message);
end
result.subtests(end+1) = entry;
end
