function [Pre, Sol] = restartFromStep(obj, stageIdx, stepK)
% RESTARTFROMSTEP  Reconstruct state at a specific converged step.
% Useful for branching studies (e.g. apply imperfection at step 5
% and re-run from there).
%
% stageIdx : stage number (1-based)
% stepK    : step index within that stage (1-based)
fprintf('[DataMgr] Restarting from stage %d, step %d...\n', ...
    stageIdx, stepK);
Pre = obj.loadPreprocessor_();
stepsFile = fullfile(obj.stagePath_(stageIdx), 'steps.mat');
if ~exist(stepsFile, 'file')
    error('[DataMgr] steps.mat not found for stage %d', stageIdx);
end
stepData = obj.loadSingleStep_(stepsFile, stepK);
chk.U      = stepData.U;
chk.lambda = stepData.lambda;
chk.step   = stepK;
Sol = obj.reconstructSolver_(Pre, chk);
Sol = obj.loadStepsIntoSolver_(Sol, stepsFile, stepK);
fprintf('[DataMgr] Step %d loaded. U_max=%.4e, lambda=%.6g\n', ...
    stepK, max(abs(Sol.U)), stepData.lambda);
end
