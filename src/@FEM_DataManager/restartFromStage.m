function [Pre, Sol] = restartFromStage(obj, stageIdx)
% RESTARTFROMSTAGE  Start of a new stage using end-state of
% a previously completed stage as the initial condition.
% Used when stages are defined in advance and earlier ones finished.
fprintf('[DataMgr] Loading end-state of stage %d as IC for next stage...\n', ...
    stageIdx);

% Find last step of the completed stage
stepsFile = fullfile(obj.stagePath_(stageIdx), 'steps.mat');
sm = obj.readJSON_(fullfile(obj.stagePath_(stageIdx), 'stage_meta.json'));
lastStep = sm.nSteps;
if lastStep < 1
    error('[DataMgr] Stage %d has no recorded steps.', stageIdx);
end

[Pre, Sol] = obj.restartFromStep(stageIdx, lastStep);
fprintf('[DataMgr] Stage %d end-state loaded (%d steps, lambda=%.4g)\n', ...
    stageIdx, lastStep, sm.lambda_last);
end
