function result = finalise_result(result)
% FINALISE_RESULT  Set result.passed = true iff all subtests passed.
% Also builds a summary string in result.details.
if isempty(result.subtests)
    result.passed  = false;
    result.details = 'No subtests were registered';
    return;
end
passed_flags = [result.subtests.passed];
n_pass = sum(passed_flags);
n_fail = sum(~passed_flags);
result.passed = (n_fail == 0);

lines = cell(1, length(result.subtests));
for k = 1:length(result.subtests)
    st = result.subtests(k);
    tag = 'PASS';
    if ~st.passed, tag = 'FAIL'; end
    lines{k} = sprintf('  [%s] %s', tag, st.name);
    if ~st.passed
        lines{k} = [lines{k}, sprintf(' — %s', st.msg)];
    end
end
result.details = sprintf('%d/%d subtests passed\n%s', ...
    n_pass, n_pass + n_fail, strjoin(lines, newline));
end
