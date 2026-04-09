function U = loadStepU(obj, stageIdx, stepK)
% LOADSTEPU  Load just the displacement vector at step k.
% Efficient: reads one variable from steps.mat without loading all.
stepsFile = fullfile(obj.stagePath_(stageIdx), 'steps.mat');
sd = obj.loadSingleStep_(stepsFile, stepK);
U  = sd.U;
end
