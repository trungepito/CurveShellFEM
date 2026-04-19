function run_all_tests(varargin)
% RUN_ALL_TESTS  Execute the full CurveShellFEM v3 test suite.
%
% Usage:
%   run_all_tests()               — run everything
%   run_all_tests('unit')         — run only unit tests
%   run_all_tests('integration')  — run only integration tests
%   run_all_tests('verification') — run only verification tests
%   run_all_tests('benchmarks')   — run only benchmarks
%   run_all_tests('fast')         — skip benchmarks and long verification tests
%
% Exit behaviour:
%   Interactive mode:  prints summary, throws error on failure.
%   Batch mode (matlab -batch): exits with code 1 on failure.
%
% All tests return a struct: .passed (logical), .name (string), .details (string).

% -------------------------------------------------------------------------
% 0. Path setup
% -------------------------------------------------------------------------
test_root = fileparts(mfilename('fullpath'));
src_root  = fullfile(test_root, '..', 'src');
addpath(genpath(src_root));
addpath(genpath(fullfile(test_root, 'helpers')));

% -------------------------------------------------------------------------
% 1. Parse filter argument
% -------------------------------------------------------------------------
filter = 'all';
if nargin >= 1 && ischar(varargin{1})
    filter = lower(varargin{1});
end

% -------------------------------------------------------------------------
% 2. Test suite definition
% -------------------------------------------------------------------------
% Format: {relative_path, suite_tag, description}
suites = { ...
    % ---- Unit tests -------------------------------------------------------
    'unit/test_assembler',              'unit', 'Assembler: symmetry, rank, zero-force, timing'; ...
    'unit/test_convergence_monitor',    'unit', 'ConvergenceMonitor: all norm types, diagnostics'; ...
    'unit/test_curve8element',          'unit', 'Curve8Element: shape fns, matrices, orthogonality'; ...
    'unit/test_material_j2plastic',     'unit', 'Material_J2Plastic: elastic/plastic, tangent, convergence'; ...
    'unit/test_solution_state',         'unit', 'SolutionState: all-mode, rolling-mode, snapshot'; ...
    'unit/test_incremental_strategies', 'unit', 'IncrementalStrategies: Riks, LoadCtrl, DispCtrl, adapt'; ...
    'unit/test_data_manager',           'unit', 'FEM_DataManager: meta, O(1) write, restart, listener'; ...
    'unit/test_solver_options',         'unit', 'SolverOptions: defaults, validation guards'; ...
    % ---- Integration tests ------------------------------------------------
    'integration/test_elastic_plate_linear',      'integration', 'Linear plate: deflection, buckling, postprocessor'; ...
    'integration/test_elastic_plate_nonlinear',   'integration', 'Nonlinear plate: 5-step load-control, history'; ...
    'integration/test_plastic_plate',             'integration', 'Plastic plate: 10-step, archive, monotone p'; ...
    'integration/test_cylindrical_panel_snapthrough', 'integration', 'Snap-through: load reversal, crown monotone'; ...
    'integration/test_buckling_eigenvalue',       'integration', 'Buckling: eigenvalues, mode shapes'; ...
    'integration/test_data_manager_pipeline',     'integration', 'DataManager pipeline: full round-trip + restart'; ...
    % ---- Verification tests -----------------------------------------------
    'verification/verify_patch_test',             'verification', 'Patch test: constant stress < 1e-8'; ...
    'verification/verify_beam_bending',           'verification', 'Beam bending: tip deflection < 2%'; ...
    'verification/verify_scordelis_lo_roof',      'verification', 'Scordelis-Lo: free-edge midpoint < 2%'; ...
    'verification/verify_cylindrical_panel_riks', 'verification', 'Crisfield Riks: peak load < 5%'; ...
    'verification/verify_plastic_thick_plate',    'verification', 'Plastic plate: limit load < 10%'; ...
    'verification/verify_replay_determinism',     'verification', 'Replay: vm_live vs vm_snapshot < 1e-8'; ...
    % ---- Benchmarks -------------------------------------------------------
    'benchmarks/bench_assembly_scaling',  'benchmarks', 'Assembly: scaling exponent b < 1.15'; ...
    'benchmarks/bench_solver_convergence','benchmarks', 'Solver: strategy comparison, L-BFGS, Riks < 60s'; ...
    'benchmarks/bench_datamanager_io',    'benchmarks', 'DataManager I/O: O(1) write, read < 10s'; ...
};

% Apply filter
skip_tags = {};
switch filter
    case 'unit'
        skip_tags = {'integration', 'verification', 'benchmarks'};
    case 'integration'
        skip_tags = {'unit', 'verification', 'benchmarks'};
    case 'verification'
        skip_tags = {'unit', 'integration', 'benchmarks'};
    case 'benchmarks'
        skip_tags = {'unit', 'integration', 'verification'};
    case 'fast'
        skip_tags = {'benchmarks'};
        % Also skip long verification tests in fast mode
        slow_verif = {'verification/verify_cylindrical_panel_riks', ...
                      'verification/verify_plastic_thick_plate'};
    case 'all'
        skip_tags = {};
    otherwise
        error('run_all_tests:badFilter', ...
              'Unknown filter ''%s''. Use: all|unit|integration|verification|benchmarks|fast', filter);
end

% -------------------------------------------------------------------------
% 3. Run
% -------------------------------------------------------------------------
n_total  = 0;
n_passed = 0;
n_failed = 0;
n_skip   = 0;
failed_names = {};
failed_details = {};

fprintf('\n');
fprintf('=================================================================\n');
fprintf(' CurveShellFEM v3 Test Suite\n');
fprintf('=================================================================\n');
fprintf(' Filter: %s\n', filter);
fprintf(' Date:   %s\n', datestr(now));
fprintf('-----------------------------------------------------------------\n');
fprintf(' %-56s  %s\n', 'Test', 'Result');
fprintf('-----------------------------------------------------------------\n');

for k = 1:size(suites, 1)
    rel_path = suites{k, 1};
    tag      = suites{k, 2};
    desc     = suites{k, 3};

    % Apply filter
    if any(strcmp(skip_tags, tag))
        n_skip = n_skip + 1;
        continue;
    end
    if strcmp(filter, 'fast') && any(strcmp(slow_verif, rel_path))
        n_skip = n_skip + 1;
        continue;
    end

    n_total = n_total + 1;

    % Resolve full path
    full_path = fullfile(test_root, strrep(rel_path, '/', filesep));
    [test_dir, func_name] = fileparts(full_path);

    % Add to path temporarily
    was_on_path = ~isempty(which(func_name));
    if ~was_on_path
        addpath(test_dir);
    end

    % Run the test
    fprintf(' %-56s  ', sprintf('[%s] %s', upper(tag(1:4)), func_name));
    t_start = tic;
    try
        result  = feval(func_name);
        elapsed = toc(t_start);

        if result.passed
            n_passed = n_passed + 1;
            fprintf('PASS  (%.1fs)\n', elapsed);
        else
            n_failed = n_failed + 1;
            fprintf('FAIL  (%.1fs)\n', elapsed);
            failed_names{end+1}   = func_name; %#ok<AGROW>
            failed_details{end+1} = result.details; %#ok<AGROW>
        end
    catch ME
        elapsed = toc(t_start);
        n_failed = n_failed + 1;
        fprintf('ERROR (%.1fs)\n', elapsed);
        failed_names{end+1}   = func_name; %#ok<AGROW>
        failed_details{end+1} = sprintf('Uncaught exception: %s\n  at %s line %d', ...
            ME.message, ME.stack(1).file, ME.stack(1).line); %#ok<AGROW>
    end

    if ~was_on_path
        rmpath(test_dir);
    end
end

% -------------------------------------------------------------------------
% 4. Summary
% -------------------------------------------------------------------------
% Write the current console summary to test_output.txt
outfile = fullfile(pwd, 'test_output.txt');
fid = fopen(outfile, 'w');
if fid == -1
    warning('run_all_tests:ioError', 'Could not open %s for writing.', outfile);
else
    % Header
    fprintf(fid, 'CurveShellFEM v3 Test Suite Summary\n');
    fprintf(fid, 'Date: %s\n', datetime('now'));
    fprintf(fid, 'Filter: %s\n\n', filter);

    % Counts
    fprintf(fid, 'PASSED:  %d / %d\n', n_passed, n_total);
    if n_skip > 0
        fprintf(fid, 'SKIPPED: %d (filter: %s)\n', n_skip, filter);
    end
    if n_failed > 0
        fprintf(fid, 'FAILED:  %d\n\n', n_failed);
        fprintf(fid, 'Failed tests:\n');
        for k = 1:length(failed_names)
            fprintf(fid, '  [%d] %s\n', k, failed_names{k});
            lines = strsplit(failed_details{k}, newline);
            for L = 1:min(length(lines), 8)
                fprintf(fid, '      %s\n', lines{L});
            end
            fprintf(fid, '\n');
        end
    else
        fprintf(fid, '\nALL TESTS PASSED\n');
    end

    fclose(fid);
end
%%
fprintf('-----------------------------------------------------------------\n');
fprintf(' PASSED:  %d / %d\n', n_passed, n_total);
if n_skip > 0
    fprintf(' SKIPPED: %d (filter: %s)\n', n_skip, filter);
end
if n_failed > 0
    fprintf(' FAILED:  %d\n', n_failed);
end

fprintf('=================================================================\n');

if n_failed > 0
    fprintf('\nFailed tests:\n');
    for k = 1:length(failed_names)
        fprintf('\n  [%d] %s\n', k, failed_names{k});
        % Print each subtest failure line
        lines = strsplit(failed_details{k}, newline);
        for L = 1:min(length(lines), 8)   % cap at 8 lines per test
            fprintf('      %s\n', lines{L});
        end
    end
    fprintf('\n');

    % Exit with error so matlab -batch returns code 1
    error('run_all_tests:failed', ...
          '%d test(s) failed. See output above for details.', n_failed);
end

fprintf('\n ALL TESTS PASSED\n\n');
end
