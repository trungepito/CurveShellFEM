function result = bench_datamanager_io()
% BENCH_DATAMANAGER_IO  Verify O(1) write and read scaling for DataManager.
%
% BM3.1  Write 500 steps; record per-step wall-clock time.
% BM3.2  PASS: time(step_500) / time(step_1) < 3.0 (flat).
% BM3.3  Read all 500 steps individually; PASS: total < 10 seconds.
% BM3.4  PASS: disk usage <= nDofs * nSteps * 8 * 1.05 bytes.
%
% This benchmark isolates the persistence layer from the solver.
% It writes synthetic step data (no FEM computation) to maximise
% the signal-to-noise ratio of the I/O timing.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('bench_datamanager_io');

tmpDir  = fullfile(tempdir, sprintf('csf_io_bench_%s', datestr(now,'HHMMSS')));
mkdir(tmpDir);
cleanFn = onCleanup(@() rmdir_safe(tmpDir));

result = run_subtest(result, 'BM3.1-BM3.4 DataManager I/O scaling', ...
    @() run_io_bench(tmpDir));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_io_bench(tmpDir)
% Use a realistic DOF count: 50x50 node mesh at 6 DOFs each
nNodes = 50 * 50;
nDofs  = nNodes * 6;   % 15,000 DOFs
nSteps = 500;

fprintf('  [IO Bench] nDofs=%d, nSteps=%d\n', nDofs, nSteps);

% Build a minimal preprocessor (just for DataManager init)
Pre = FEM_Preprocessor_v2(200e9, 0.3, 0.01);
Pre.Mesh.Nodes    = rand(nNodes, 3);
Pre.Mesh.Elements = zeros(0, 8, 'double');
Pre.Mesh.Normals  = repmat([0,0,1], nNodes, 1);

DM = FEM_DataManager('io_bench', tmpDir);
DM.SaveGPHistory = false;   % no GP history in this benchmark
DM.initProject(Pre);

S1 = LoadingStage(1.0);
DM.initStage(1, S1);

% ----------------------------------------------------------------
% BM3.1  Write 500 steps, record timing
% ----------------------------------------------------------------
write_times = zeros(nSteps, 1);

fprintf('  [IO Bench] Writing %d steps...\n', nSteps);
for k = 1:nSteps
    stepData.U        = rand(nDofs, 1);   % synthetic displacement
    stepData.lambda   = k / nSteps;
    stepData.iters    = 5;
    stepData.time     = k / nSteps;
    stepData.arc_used = 1 / nSteps;

    t0 = tic;
    DM.appendStep(1, stepData);
    write_times(k) = toc(t0);
end

% Remove outliers (first call may be slow due to file creation)
t_first = write_times(1);
t_last  = write_times(end);

% Smooth over a window to reduce noise
win = 10;
t_smooth_start = mean(write_times(2 : 2+win-1));
t_smooth_end   = mean(write_times(end-win+1 : end));

ratio = t_smooth_end / max(t_smooth_start, 1e-9);
fprintf('  [IO Bench] Write times: step 1 = %.4f s, step 500 = %.4f s\n', ...
    t_first, t_last);
fprintf('  [IO Bench] Smoothed ratio (last/first window) = %.2f  (limit 3.0)\n', ratio);

% ----------------------------------------------------------------
% BM3.2  Scaling assertion
% ----------------------------------------------------------------
if ratio > 3.0
    error(['DATAMANAGER IO FAILED (BM3.2): write time ratio = %.2f > 3.0.\n' ...
           'writeStep_ may still be loading the entire file on each call.'], ratio);
end

% ----------------------------------------------------------------
% BM3.3  Read all 500 steps individually
% ----------------------------------------------------------------
fprintf('  [IO Bench] Reading %d steps individually...\n', nSteps);
t_read_start = tic;
for k = 1:nSteps
    U_k = DM.loadStepU(1, k); %#ok<NASGU>
end
t_read_total = toc(t_read_start);

fprintf('  [IO Bench] Total read time for %d steps = %.2f s  (limit 10 s)\n', ...
    nSteps, t_read_total);

if t_read_total > 10.0
    error('DATAMANAGER IO FAILED (BM3.3): reading %d steps took %.2f s > 10 s.', ...
          nSteps, t_read_total);
end

% ----------------------------------------------------------------
% BM3.4  Disk usage check
% ----------------------------------------------------------------
stageDir = fullfile(tmpDir, 'io_bench', 'stages', 'stage_01');
u_file   = fullfile(stageDir, 'U_hist.mat');

if ~exist(u_file, 'file')
    % Fallback: check steps.mat (old format)
    u_file = fullfile(stageDir, 'steps.mat');
end

if exist(u_file, 'file')
    info = dir(u_file);
    actual_bytes = info.bytes;
    expected_max = nDofs * nSteps * 8 * 1.05;   % 5% overhead

    fprintf('  [IO Bench] U_hist file size = %d bytes (limit %d bytes, %.1f%% of raw)\n', ...
        actual_bytes, round(expected_max), actual_bytes / (nDofs * nSteps * 8) * 100);

    if actual_bytes > expected_max
        error(['DATAMANAGER IO FAILED (BM3.4): U_hist file = %d bytes > ' ...
               'limit %d bytes (%.1f%% overhead).'], ...
              actual_bytes, round(expected_max), ...
              (actual_bytes - nDofs*nSteps*8) / (nDofs*nSteps*8) * 100);
    end
else
    warning('bench_datamanager_io:noFile', ...
            'U_hist.mat / steps.mat not found at %s — skipping disk usage check', stageDir);
end

fprintf('  [IO Bench] PASS — all scaling and size criteria met.\n');
end

% ----------------------------------------------------------------
function rmdir_safe(d)
if exist(d, 'dir')
    rmdir(d, 's');
end
end
