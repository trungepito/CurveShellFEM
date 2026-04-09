function initStage(obj, stageIdx, Stage)
% INITSTAGE  Create stage directory and write stage_meta.json.
% stageIdx : integer (1-based)
% Stage    : LoadingStage object
stageDir = obj.stagePath_(stageIdx);
obj.ensureDir_(stageDir);

% Stage meta
sm = struct();
sm.stage_index      = stageIdx;
sm.constraint_type  = 'unknown';
sm.duration         = Stage.Duration;
sm.arc_radius       = Stage.ArcLengthRadius;
sm.arc_min          = Stage.ArcLengthMin;
sm.arc_max          = Stage.ArcLengthMax;
sm.active_bcs       = Stage.ActiveBCs;
sm.active_loads     = Stage.ActiveLoads;
sm.started          = datetime("now","Format","dd-MMM-uuuu HH:mm:ss");
sm.status           = 'in_progress';
sm.nSteps           = 0;
sm.lambda_last      = 0;

if isprop(Stage, 'ConstraintType')
    sm.constraint_type = Stage.ConstraintType;
end

obj.writeJSON_(fullfile(stageDir, 'stage_meta.json'), sm);

% Update project meta
meta = obj.readMeta_();
meta.nStages = max(meta.nStages, stageIdx);
meta.status  = 'in_progress';

% Grow stages array if needed
if isempty(meta.stages)
    meta.stages = repmat(struct('index',0,'nSteps',0,...
        'lambda_last',0,'status','pending'), stageIdx, 1);
elseif length(meta.stages) < stageIdx
    extra = repmat(struct('index',0,'nSteps',0,...
        'lambda_last',0,'status','pending'), ...
        stageIdx - length(meta.stages), 1);
    meta.stages = [meta.stages; extra];
end
meta.stages(stageIdx).index  = stageIdx;
meta.stages(stageIdx).status = 'in_progress';
obj.writeMeta_(meta);

obj.StepCounters_(int32(stageIdx)) = int32(0);
fprintf('[DataMgr] Stage %d initialized.\n', stageIdx);
end
