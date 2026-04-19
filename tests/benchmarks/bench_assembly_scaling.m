function result = bench_assembly_scaling()
% BENCH_ASSEMBLY_SCALING  Verify near-linear scaling of Assembler.elastic.
%
% BM1.1  Time Assembler.elastic at 4 mesh sizes: 100, 400, 900, 1600 elements.
% BM1.2  Fit power law T = a * N^b; PASS: b < 1.15 (near-linear scaling).
% BM1.3  PASS: 1600-element assembly completes in < 30 seconds.
%
% Rationale: Assembly is dominated by the triplet-construction loop (O(N))
% and sparse-matrix construction (O(N log N) in the worst case). The bound
% b < 1.15 is conservative enough to catch accidentally quadratic code paths.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('bench_assembly_scaling');

result = run_subtest(result, 'BM1.1-BM1.3 assembly scaling', @() run_assembly_bench());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_assembly_bench()
E  = 200e9;
nu = 0.3;
t  = 0.02;
L  = 1.0;

% Mesh sizes: n_side x n_side → n_side^2 elements
n_sides = [10, 20, 30, 40];   % 100, 400, 900, 1600 elements
n_elems = n_sides .^ 2;
n_meshes = length(n_sides);

times    = zeros(n_meshes, 1);
n_dofs   = zeros(n_meshes, 1);

fprintf('  [Assembly Bench]\n');
fprintf('  %-12s  %-8s  %-10s\n', 'Elements', 'DOFs', 'Time (s)');
fprintf('  %s\n', repmat('-', 1, 36));

for k = 1:n_meshes
    ns = n_sides(k);
    Pre = make_plate_model('E', E, 'nu', nu, 't', t, 'L', L, 'Ne', ns, 'bc', 'clamped');
    Sol = FEM_Solver(Pre);
    nd  = size(Pre.Mesh.Nodes, 1) * 6;
    n_dofs(k) = nd;

    % Warm-up run (first call may include JIT compilation overhead)
    Assembler.elastic(Sol.Elements, Sol.SctrMap, nd);

    % Timed run (average of 3 to reduce noise)
    reps = 3;
    t0 = tic;
    for r = 1:reps
        Assembler.elastic(Sol.Elements, Sol.SctrMap, nd);
    end
    times(k) = toc(t0) / reps;

    fprintf('  %-12d  %-8d  %.4f\n', n_elems(k), nd, times(k));
end

% ----------------------------------------------------------------
% BM1.2  Fit power law: log(T) = log(a) + b * log(N)
% ----------------------------------------------------------------
log_N = log(n_elems(:));
log_T = log(times);

% Linear regression in log-log space
A_fit = [ones(n_meshes,1), log_N];
coefs = A_fit \ log_T;
b_fit = coefs(2);

fprintf('\n  Power law fit: T = %.4e * N^%.3f\n', exp(coefs(1)), b_fit);
fprintf('  Scaling exponent b = %.3f  (pass if b < 1.15)\n', b_fit);

if b_fit >= 1.15
    error(['ASSEMBLY SCALING FAILED: scaling exponent b = %.3f >= 1.15.\n' ...
           'Assembly is super-linear — likely a non-pre-allocated array growth.'], b_fit);
end

% ----------------------------------------------------------------
% BM1.3  1600-element assembly < 30 seconds
% ----------------------------------------------------------------
t_large = times(end);
fprintf('  1600-element assembly time: %.2f s  (limit 30 s)\n', t_large);

if t_large > 30.0
    error('ASSEMBLY BENCH FAILED: 1600-element assembly took %.2f s > 30 s limit.', t_large);
end

fprintf('  [Assembly Bench] PASS — b=%.3f < 1.15, t_1600=%.2f s < 30 s\n', ...
    b_fit, t_large);
end
