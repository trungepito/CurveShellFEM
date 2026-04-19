function result = verify_replay_determinism()
% VERIFY_REPLAY_DETERMINISM  Snapshot serialization and replay consistency.
%
% VT6.1  Run 15-step Riks analysis; save SolutionSnapshot to disk.
% VT6.2  Load snapshot; construct FEM_Postprocessor_v2 from it.
% VT6.3  Recover von_mises at step 15 from live solver AND from snapshot.
% VT6.4  PASS: max|vm_live - vm_replay| < 1e-8 (bit-exact).
% VT6.5  Snapshot is independent: clear solver, post-processing still works.
%
% This test validates the entire commit/snapshot/archive pipeline.
% If it fails, the P0 bugs (double commit, dual write paths) are likely
% not fully resolved.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('verify_replay_determinism');

% Use a small model to keep runtime manageable
tmpDir  = fullfile(tempdir, sprintf('csf_replay_%s', datestr(now,'HHMMSS')));
mkdir(tmpDir);
cleanFn = onCleanup(@() rmdir_safe(tmpDir));

result = run_subtest(result, 'VT6.1-VT6.5 snapshot replay determinism', ...
    @() run_replay_test(tmpDir));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_replay_test(tmpDir)
% ----------------------------------------------------------------
% VT6.1  Build and run 15-step Riks analysis on a flat plate.
%        (A flat plate will show no snap-through but tests the full
%         archive/snapshot pipeline with a stable, repeatable solution.)
% ----------------------------------------------------------------
E  = 200e9;
nu = 0.3;
t  = 0.02;
L  = 1.0;
q  = 300;    % Pa per step

Pre = make_plate_model('E', E, 'nu', nu, 't', t, 'L', L, 'Nu', 3, 'bc', 'clamped');
Pre.addPressureLoad((1:size(Pre.Mesh.Elements,1))', q, 'Pressure');

nNodes = size(Pre.Mesh.Nodes, 1);

opts = SolverOptions();
opts.MaxIterations = 20;
opts.TolForce      = 1e-5;
Sol = FEM_Solver_Nonlinear(Pre, opts);

S1 = LoadingStage(1.0);
S1.ConstraintType  = 'LoadControl';
S1.ArcLengthRadius = 1/15;   % 15 equal steps
S1.activateBC('Clamp');
S1.activateLoad('Pressure');

Sol.solve({S1});

if Sol.StepCount < 15
    error('Expected 15 converged steps, got %d', Sol.StepCount);
end
fprintf('  [Replay] Completed %d Riks steps.\n', Sol.StepCount);

% ----------------------------------------------------------------
% VT6.3a  Recover von_mises at step 15 from LIVE solver
% ----------------------------------------------------------------
Post_live = FEM_Postprocessor_v2(Pre, Sol);
vm_live   = Post_live.recoverField('von_mises', 15);

fprintf('  [Replay] Live von_mises at step 15: max = %.6e Pa\n', max(vm_live));

% ----------------------------------------------------------------
% VT6.1 (cont.)  Save snapshot to disk via DataManager
% ----------------------------------------------------------------
DM = FEM_DataManager('replay_test', tmpDir);
DM.initProject(Pre);
snap_live = Sol.state.snapshot();

% Serialise the snapshot struct to MAT
snap_file = fullfile(tmpDir, 'replay_snapshot.mat');
save(snap_file, 'snap_live', '-v7.3');
fprintf('  [Replay] Snapshot saved to %s\n', snap_file);

% ----------------------------------------------------------------
% VT6.2  Load snapshot and build postprocessor from it
% ----------------------------------------------------------------
loaded = load(snap_file, 'snap_live');
snap_loaded = loaded.snap_live;

if snap_loaded.StepCount ~= 15
    error('Loaded snapshot has StepCount=%d, expected 15', snap_loaded.StepCount);
end

% We need Elements and SctrMap from a reconstructed solver for GPrecovery.
% Reconstruct a solver (no solve needed, just element cache)
Sol_dummy = FEM_Solver_Nonlinear(Pre, opts);
% Inject the loaded snapshot into its state
Post_replay = FEM_Postprocessor_v2(Pre, Sol_dummy);
% Override the internal snapshot with the loaded one
% (This tests that the snapshot interface works correctly)
Post_replay_from_snap = FEM_Postprocessor_v2_from_snap(Pre, snap_loaded, Sol_dummy);

% ----------------------------------------------------------------
% VT6.3b / VT6.4  Compare live vs replay
% ----------------------------------------------------------------
vm_replay = Post_replay_from_snap.recoverField('von_mises', 15);

max_diff  = max(abs(vm_live - vm_replay));
fprintf('  [Replay] max|vm_live - vm_replay| = %.3e  (tol 1e-8)\n', max_diff);

if max_diff > 1e-8
    error(['REPLAY DETERMINISM FAILED: max|vm_live - vm_replay| = %g > 1e-8.\n' ...
           'The commit/snapshot/archive pipeline has inconsistencies.'], max_diff);
end

% ----------------------------------------------------------------
% VT6.5  Independence: clear Sol, post-processing still works
% ----------------------------------------------------------------
clear Sol Post_live;   % release live solver

vm_after_clear = Post_replay_from_snap.recoverField('von_mises', 15);
max_diff2 = max(abs(vm_live - vm_after_clear));

fprintf('  [Replay] After clearing solver: max|vm| deviation = %.3e\n', max_diff2);
if max_diff2 > 1e-8
    error(['REPLAY INDEPENDENCE FAILED: recoverField failed or changed after ' ...
           'clearing the solver. max diff = %g.'], max_diff2);
end

fprintf('  [Replay] Snapshot is fully independent of the live solver.\n');
end

% ----------------------------------------------------------------
function Post = FEM_Postprocessor_v2_from_snap(model, snap, sol_with_elements)
% Helper: construct postprocessor using a pre-built snapshot.
% This is the intended usage pattern post Wave 3 (Task 10):
%   The constructor accepts a SolutionSnapshot directly.
Post = FEM_Postprocessor_v2(model, snap);
% Inject element cache from the reconstructed (but not solved) solver
% so that GP recovery can proceed.
Post.Elements = sol_with_elements.Elements;
Post.SctrMap  = sol_with_elements.SctrMap;
end

% ----------------------------------------------------------------
function rmdir_safe(d)
if exist(d, 'dir')
    rmdir(d, 's');
end
end
