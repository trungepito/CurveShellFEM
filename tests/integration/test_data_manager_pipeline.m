function result = test_data_manager_pipeline()
% TEST_DATA_MANAGER_PIPELINE  End-to-end DataManager integration test.
%
% Covers IT6.1-IT6.4:
%   IT6.1  Full pipeline: initProject -> solve -> finalize -> status == 'complete'
%   IT6.2  restartFromCheckpoint returns Sol with correct StepCount
%   IT6.3  loadStageHistory returns correct U_hist and lambda_hist dimensions
%   IT6.4  listRestartPoints reports nSteps == 10

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_data_manager_pipeline');

% Temp directory for all test artefacts
tmpDir  = fullfile(tempdir, sprintf('csf_dm_pipeline_%s', datestr(now,'HHMMSS')));
mkdir(tmpDir);
cleanFn = onCleanup(@() rmdir_safe(tmpDir));

% ----------------------------------------------------------------
% Build a small model: 2x2 clamped plate, 10 load-control steps
% ----------------------------------------------------------------
E  = 200e9;
nu = 0.3;
t  = 0.02;
L  = 1.0;
q  = 200;   % Pa per step
nStepsTarget = 10;

Pre = make_plate_model('E', E, 'nu', nu, 't', t, 'L', L, 'Ne', 2, 'bc', 'clamped');
Pre.addPressureLoad((1:size(Pre.Mesh.Elements,1))', q, 'Pressure');

nDofs = size(Pre.Mesh.Nodes, 1) * 6;

opts = SolverOptions();
opts.MaxIterations = 15;
opts.TolForce      = 1e-5;
Sol = FEM_Solver_Nonlinear(Pre, opts);

% Stage: 10 equal steps via LoadControl
S1 = LoadingStage(1.05); % wierd fixed!!!!
S1.ConstraintType  = 'LoadControl';
S1.ArcLengthRadius = 0.1;   % 10 steps at ds=0.1
S1.activateBC('Clamp');
S1.activateLoad('Pressure');

% Wire DataManager BEFORE solving
DM = FEM_DataManager('pipeline_test', tmpDir);
DM.CheckpointInterval = 5;
DM.initProject(Pre);
DM.initStage(1, S1);
DM.attachToSolver(Sol, 1);

Sol.solve({S1});

DM.finalizeStage(1, Sol.LambdaHist(end));
DM.finalizeProject();

% ----------------------------------------------------------------
% IT6.1 — project_meta.json has status == 'complete'
% ----------------------------------------------------------------
result = run_subtest(result, 'IT6.1 project status is complete', ...
    @() it6_1(tmpDir));

% ----------------------------------------------------------------
% IT6.2 — restartFromCheckpoint returns Sol with StepCount == CheckpointInterval
% ----------------------------------------------------------------
result = run_subtest(result, 'IT6.2 restartFromCheckpoint StepCount', ...
    @() it6_2(tmpDir, DM.CheckpointInterval));

% ----------------------------------------------------------------
% IT6.3 — loadStageHistory returns [nDofs x 10] U_hist
% ----------------------------------------------------------------
result = run_subtest(result, 'IT6.3 loadStageHistory dimensions', ...
    @() it6_3(tmpDir, nDofs, nStepsTarget));

% ----------------------------------------------------------------
% IT6.4 — listRestartPoints reports nSteps == 10
% ----------------------------------------------------------------
result = run_subtest(result, 'IT6.4 listRestartPoints reports nSteps', ...
    @() it6_4(tmpDir, nStepsTarget));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function it6_1(tmpDir)
metaPath = fullfile(tmpDir, 'pipeline_test', 'project_meta.json');
if ~exist(metaPath, 'file')
    error('project_meta.json not found at %s', metaPath);
end
meta = jsondecode(fileread(metaPath));
if ~strcmp(meta.status, 'complete')
    error('project status = ''%s'', expected ''complete''', meta.status);
end
end

% ----------------------------------------------------------------
function it6_2(tmpDir, checkpointInterval)
DM2 = FEM_DataManager('pipeline_test', tmpDir);
[~, Sol2] = DM2.restartFromCheckpoint(1);
if Sol2.StepCount ~= checkpointInterval
    error('Restart StepCount = %d, expected %d (CheckpointInterval)', ...
          Sol2.StepCount, checkpointInterval);
end
end

% ----------------------------------------------------------------
function it6_3(tmpDir, nDofs, nStepsTarget)
DM2 = FEM_DataManager('pipeline_test', tmpDir);
[U_hist, lambda_hist] = DM2.loadStageHistory(1);

if size(U_hist, 1) ~= nDofs
    error('U_hist has %d rows, expected nDofs=%d', size(U_hist,1), nDofs);
end
if size(U_hist, 2) ~= nStepsTarget
    error('U_hist has %d columns, expected nStepsTarget=%d', ...
          size(U_hist,2), nStepsTarget);
end
if length(lambda_hist) ~= nStepsTarget
    error('lambda_hist has %d entries, expected %d', ...
          length(lambda_hist), nStepsTarget);
end

% Lambda must be non-decreasing for load-control
if any(diff(lambda_hist) < -1e-12)
    error('lambda_hist is not non-decreasing for load-control analysis');
end
end

% ----------------------------------------------------------------
function it6_4(tmpDir, nStepsTarget)
DM2  = FEM_DataManager('pipeline_test', tmpDir);
info = DM2.listRestartPoints();
if isempty(info)
    error('listRestartPoints returned empty struct');
end
if info(1).nSteps ~= nStepsTarget
    error('Stage 1 nSteps = %d, expected %d', info(1).nSteps, nStepsTarget);
end
end

% ----------------------------------------------------------------
function rmdir_safe(d)
if exist(d, 'dir')
    rmdir(d, 's');
end
end
