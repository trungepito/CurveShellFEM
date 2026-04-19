function result = test_data_manager()
% TEST_DATA_MANAGER  Unit tests for FEM_DataManager persistence layer.
%
% Covers UT7.1–UT7.5 from the implementation plan.
%   UT7.1  initProject creates project_meta.json with required fields
%   UT7.2  writeStep_ shows O(1) write time over 50 steps
%   UT7.3  loadSingleStep_ reads step 25 without loading all steps
%   UT7.4  restartFromCheckpoint returns solver with correct StepCount
%   UT7.5  delete(DataManager) invalidates listeners

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_data_manager');

% Use a temporary directory for all test output
tmpDir = fullfile(tempdir, sprintf('csf_dm_test_%s', datestr(now,'HHMMSS')));
mkdir(tmpDir);

cleanFn = onCleanup(@() rmdir_safe(tmpDir));

% Build a minimal model for DataManager tests
Pre = make_plate_model('E', 2.1e11, 'nu', 0.3, 't', 0.01, 'L', 1.0, 'Nu', 2, 'bc', 'clamped');
nDofs = size(Pre.Mesh.Nodes, 1) * 6;

% ----------------------------------------------------------------
% UT7.1 — initProject creates project_meta.json
% ----------------------------------------------------------------
result = run_subtest(result, 'UT7.1 initProject creates meta JSON', ...
    @() ut7_1(Pre, tmpDir));

% ----------------------------------------------------------------
% UT7.2 — writeStep_ shows O(1) write time
% ----------------------------------------------------------------
result = run_subtest(result, 'UT7.2 writeStep_ O(1) scaling', ...
    @() ut7_2(Pre, nDofs, tmpDir));

% ----------------------------------------------------------------
% UT7.3 — loadSingleStep_ reads individual step efficiently
% ----------------------------------------------------------------
result = run_subtest(result, 'UT7.3 loadSingleStep_ returns correct U', ...
    @() ut7_3(nDofs, tmpDir));

% ----------------------------------------------------------------
% UT7.4 — restartFromCheckpoint reconstructs solver
% ----------------------------------------------------------------
result = run_subtest(result, 'UT7.4 restartFromCheckpoint StepCount', ...
    @() ut7_4(Pre, nDofs, tmpDir));

% ----------------------------------------------------------------
% UT7.5 — delete(DataManager) invalidates listeners
% ----------------------------------------------------------------
result = run_subtest(result, 'UT7.5 delete invalidates listeners', ...
    @() ut7_5(Pre, tmpDir));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function ut7_1(Pre, tmpDir)
DM = FEM_DataManager('ut71_proj', tmpDir);
DM.initProject(Pre);

metaPath = fullfile(tmpDir, 'ut71_proj', 'project_meta.json');
if ~exist(metaPath, 'file')
    error('project_meta.json was not created at %s', metaPath);
end

raw  = fileread(metaPath);
meta = jsondecode(raw);

requiredFields = {'project_name', 'nStages', 'status', 'created'};
for k = 1:length(requiredFields)
    f = requiredFields{k};
    if ~isfield(meta, f)
        error('project_meta.json missing field: %s', f);
    end
end

if ~strcmp(meta.status, 'initialized')
    error('Initial status should be ''initialized'', got ''%s''', meta.status);
end
end

% ----------------------------------------------------------------
function ut7_2(Pre, nDofs, tmpDir)
% Write 50 steps; assert time(step 50) < 3 * time(step 1).
DM = FEM_DataManager('ut72_proj', tmpDir);
DM.initProject(Pre);

S1 = LoadingStage(1.0);
S1.activateBC('Clamp');
DM.initStage(1, S1);

times = zeros(50, 1);
for k = 1:50
    stepData.U        = k * ones(nDofs, 1);
    stepData.lambda   = k * 0.02;
    stepData.iters    = 5;
    stepData.time     = k * 0.02;
    stepData.arc_used = 0.02;
    t0 = tic;
    DM.appendStep(1, stepData);
    times(k) = toc(t0);
end

ratio = times(50) / max(times(1), 1e-9);
if ratio > 3.0
    error('Write time ratio (step50/step1) = %.2f > 3.0 — O(N) detected', ratio);
end
end

% ----------------------------------------------------------------
function ut7_3(nDofs, tmpDir)
% Verify that loadStepU on step 25 returns the correct U vector.
% The data was written by ut7_2.
DM = FEM_DataManager('ut72_proj', tmpDir);   % same project

U25 = DM.loadStepU(1, 25);

if ~isequal(size(U25), [nDofs, 1])
    error('loadStepU returned size [%d %d], expected [%d 1]', ...
          size(U25, 1), size(U25, 2), nDofs);
end

expected_val = 25;
if abs(U25(1) - expected_val) > 1e-10
    error('loadStepU(1, 25)(1) = %g, expected %g', U25(1), expected_val);
end
end

% ----------------------------------------------------------------
function ut7_4(Pre, nDofs, tmpDir)
% Write CheckpointInterval steps, then restartFromCheckpoint.
DM = FEM_DataManager('ut74_proj', tmpDir);
DM.CheckpointInterval = 5;
DM.initProject(Pre);

S1 = LoadingStage(1.0);
S1.activateBC('Clamp');
DM.initStage(1, S1);

% Write exactly CheckpointInterval steps so a checkpoint exists
for k = 1:DM.CheckpointInterval
    stepData.U        = k * ones(nDofs, 1);
    stepData.lambda   = k * 0.1;
    stepData.iters    = 3;
    stepData.time     = k * 0.1;
    stepData.arc_used = 0.1;
    DM.appendStep(1, stepData);
end

[Pre2, Sol2] = DM.restartFromCheckpoint(1); %#ok<ASGLU>

if Sol2.StepCount ~= DM.CheckpointInterval
    error('Restart StepCount = %d, expected %d (CheckpointInterval)', ...
          Sol2.StepCount, DM.CheckpointInterval);
end
end

% ----------------------------------------------------------------
function ut7_5(Pre, tmpDir)
% After delete(DM), all listeners must be invalid.
DM = FEM_DataManager('ut75_proj', tmpDir);
DM.initProject(Pre);

opts = SolverOptions();
Sol  = FEM_Solver_Nonlinear(Pre, opts);

S1 = LoadingStage(1.0);
S1.activateBC('Clamp');
DM.initStage(1, S1);
DM.attachToSolver(Sol, 1);

% Capture listener handles BEFORE delete
listeners_before = DM.Listeners_;

delete(DM);

% All handles must now be invalid
for k = 1:length(listeners_before)
    if isvalid(listeners_before{k})
        error('Listener %d is still valid after delete(DataManager)', k);
    end
end
end

% ----------------------------------------------------------------
function rmdir_safe(d)
if exist(d, 'dir')
    rmdir(d, 's');
end
end
