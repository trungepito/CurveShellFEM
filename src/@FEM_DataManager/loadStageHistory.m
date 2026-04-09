function [U_hist, lambda_hist] = loadStageHistory(obj, stageIdx)
% LOADSTAGEHISTORY  Load full U_Hist and LambdaHist for one stage.
stepsFile = fullfile(obj.stagePath_(stageIdx), 'steps.mat');
if ~exist(stepsFile, 'file')
    error('[DataMgr] steps.mat not found for stage %d', stageIdx);
end
tmp = load(stepsFile, 'header');
n   = tmp.header.nSteps;
if n == 0
    U_hist      = [];
    lambda_hist = [];
    return;
end
% Load first step to determine nDofs
s1 = obj.loadSingleStep_(stepsFile, 1);
nDofs       = length(s1.U);
U_hist      = zeros(nDofs, n);
lambda_hist = zeros(1, n);
for k = 1:n
    sd             = obj.loadSingleStep_(stepsFile, k);
    U_hist(:,k)    = sd.U;
    lambda_hist(k) = sd.lambda;
end
end
