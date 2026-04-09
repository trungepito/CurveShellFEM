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
% Strategy: store all steps inside a single struct 'steps' where
% steps.(step_00001) = sd.  This avoids eval() while keeping
% individual-variable load semantics via struct field access.
sd = struct('U',      stepData.U, ...
            'lambda', stepData.lambda, ...
            'iters',  stepData.iters, ...
            'time',   stepData.time, ...
            'arc_used', stepData.arc_used);
varName = sprintf('step_%05d', double(n));

if ~exist(stepsFile, 'file')
    header.nSteps      = double(n);
    header.stage_index = stageIdx;
    header.created     = datetime("now","Format","dd-MMM-uuuu HH:mm:ss");
    steps.(varName)    = sd; %#ok<STRNU>
    save(stepsFile, 'header', 'steps', '-v7.3');
else
    % Load existing steps struct, add new field, re-save.
    % For large problems (>500 steps), consider switching to
    % one-var-per-file layout or HDF5 (see INTEGRATION_NOTES).
    tmp            = load(stepsFile, 'header', 'steps');
    header         = tmp.header;
    header.nSteps  = double(n);
    if isfield(tmp, 'steps')
        steps = tmp.steps;
    else
        steps = struct();
    end
    steps.(varName) = sd;
    save(stepsFile, 'header', 'steps', '-v7.3');
end

% --- write GP history (plastic problems only) ---
if isfield(stepData, 'GPHistory') && ~isempty(stepData.GPHistory)
    gpFile = fullfile(stageDir, 'gp_history.mat');
    gpVar  = sprintf('gp_step_%05d', double(n));
    if ~exist(gpFile, 'file')
        gpHistory.(gpVar) = stepData.GPHistory; %#ok<STRNU>
        save(gpFile, 'gpHistory', '-v7.3');
    else
        tmp2 = load(gpFile, 'gpHistory');
        if isfield(tmp2, 'gpHistory')
            gpHistory = tmp2.gpHistory;
        else
            gpHistory = struct();
        end
        gpHistory.(gpVar) = stepData.GPHistory;
        save(gpFile, 'gpHistory', '-v7.3');
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
