function [Pre, Sol] = restartFromStage(obj, stageId)
%RESTARTFROMSTAGE Restart solver from latest converged step in a stage.

if nargin < 2 || isempty(stageId)
    stageId = 1;
end

[Pre, Sol] = obj.loadSnapshot('project');
root = obj.getProjectRoot();
stageDir = fullfile(root, 'stages', sprintf('stage_%03d', stageId));
stepsFile = fullfile(stageDir, 'steps.mat');

if ~exist(stepsFile, 'file')
    warning('[DataMgr] No steps.mat found for stage %d. Using project checkpoint only.', stageId);
    return;
end

metaFile = fullfile(stageDir, 'stage_meta.json');
if exist(metaFile, 'file')
    sm = jsondecode(fileread(metaFile));
    if isfield(sm, 'lastStep') && sm.lastStep > 0
        stepId = sm.lastStep;
    else
        stepId = findLatestStep(stepsFile);
    end
else
    stepId = findLatestStep(stepsFile);
end

[Pre, Sol] = obj.restartFromStep(stageId, stepId);
end

function k = findLatestStep(stepsFile)
vars = who('-file', stepsFile);
k = 0;
for i = 1:numel(vars)
    t = regexp(vars{i}, '^U_step_(\d+)$', 'tokens', 'once');
    if ~isempty(t)
        k = max(k, str2double(t{1}));
    end
end
if k == 0
    error('No U_step_k variables found in %s', stepsFile);
end
end
