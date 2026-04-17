function writeStep_(obj, stageIdx, stepData)
% Core incremental writer.  Appends one step to steps.mat and
% optionally to gp_history.mat, then conditionally updates checkpoint.

% --- increment internal counter ---
key = int32(stageIdx);
if obj.StepCounters_.isKey(key)
    n = obj.StepCounters_(key) + int32(1);
else
    % Determine from existing file (resume scenario)
    stepsFile = fullfile(obj.stagePath_(stageIdx), 'steps.mat');
    if exist(stepsFile, 'file')
        tmp = load(stepsFile, 'header');
        n   = int32(tmp.header.nSteps) + int32(1);
    else
        n = int32(1);
    end
end
obj.StepCounters_(key) = n;

stageDir  = obj.stagePath_(stageIdx);
obj.ensureDir_(stageDir);
stepsFile = fullfile(stageDir, 'steps.mat');

% --- write/append steps.mat ---
% Strategy: store each step as a top-level variable step_00001, etc.
% This allows O(1) appending using matfile() without loading existing steps.
sd = struct('U',      stepData.U, ...
            'lambda', stepData.lambda, ...
            'iters',  stepData.iters, ...
            'time',   stepData.time, ...
            'arc_used', stepData.arc_used);
varName = sprintf('step_%05d', double(n));

header.nSteps      = double(n);
header.stage_index = stageIdx;
header.created     = datetime("now","Format","dd-MMM-uuuu HH:mm:ss");

if ~exist(stepsFile, 'file')
    save(stepsFile, 'header', '-v7.3');
    mf = matfile(stepsFile, 'Writable', true);
    mf.(varName) = sd;
else
    mf = matfile(stepsFile, 'Writable', true);
    mf.header = header;
    mf.(varName) = sd;
end

% --- write GP history (plastic problems only) ---
if isfield(stepData, 'GPHistory') && ~isempty(stepData.GPHistory)
    gpFile = fullfile(stageDir, 'gp_history.mat');
    gpVar  = sprintf('gp_step_%05d', double(n));
    if ~exist(gpFile, 'file')
        gpDat = stepData.GPHistory;
        save(gpFile, 'gpDat', '-v7.3'); % Use dummy gpDat if only one var
        mfGP = matfile(gpFile, 'Writable', true);
        mfGP.(gpVar) = stepData.GPHistory;
    else
        mfGP = matfile(gpFile, 'Writable', true);
        mfGP.(gpVar) = stepData.GPHistory;
    end
end

% --- update stage meta every step ---
smFile = fullfile(stageDir, 'stage_meta.json');
if exist(smFile, 'file')
    sm = obj.readJSON_(smFile);
    sm.nSteps    = double(n);
    sm.lambda_last = stepData.lambda;
    obj.writeJSON_(smFile, sm);
end

% --- update project meta every step ---
metaFile = obj.metaPath_();
if exist(metaFile, 'file')
    meta = obj.readMeta_();
    if ~isempty(meta.stages) && length(meta.stages) >= stageIdx
        meta.stages(stageIdx).nSteps     = double(n);
        meta.stages(stageIdx).lambda_last = stepData.lambda;
    end
    obj.writeMeta_(meta);
end

% --- checkpoint every N steps ---
if mod(n, obj.CheckpointInterval) == 0
    obj.writeCheckpoint_(stageIdx, stepData, double(n));
end
end
