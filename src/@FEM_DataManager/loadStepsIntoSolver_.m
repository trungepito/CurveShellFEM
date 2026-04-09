function Sol = loadStepsIntoSolver_(obj, Sol, stepsFile, upToStep)
% Populate Sol.U_Hist, Sol.LambdaHist, Sol.History_Time from steps.mat
data = load(stepsFile, 'header');
n    = data.header.nSteps;
if nargin >= 4
    n = min(n, upToStep);
end
if n == 0, return; end
s1 = obj.loadSingleStep_(stepsFile, 1);
nDofs = length(s1.U);
U_hist      = zeros(nDofs, n);
lambda_hist = zeros(1, n);
time_hist   = zeros(n, 1);
for k = 1:n
    sd              = obj.loadSingleStep_(stepsFile, k);
    U_hist(:,k)     = sd.U;
    lambda_hist(k)  = sd.lambda;
    time_hist(k)    = sd.time;
end
Sol.U_Hist      = U_hist;
Sol.StepCount   = n;
Sol.U           = U_hist(:, n);
if isprop(Sol, 'LambdaHist')
    Sol.LambdaHist  = lambda_hist;
end
Sol.History_Time = time_hist;
end
