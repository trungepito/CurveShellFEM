function onStepConverged(obj, src, evt, stageId)
%ONSTEPCONVERGED Event callback to persist converged solver step.

if nargin < 5 || isempty(stageId)
    stageId = 1;
end

payload = struct();
payload.step = evt.StepNumber;
payload.time = evt.Time;
payload.lambda = evt.LoadFactor;
payload.iterations = evt.Iterations;
payload.status = 'converged';
payload.U = evt.U;

obj.appendStep(stageId, payload);

% Rolling checkpoint update for quick recovery
root = obj.getProjectRoot();
chk = struct();
chk.solverClass = class(src);
chk.savedAt = datestr(now, 30);
chk.U = src.U;
if isprop(src, 'LambdaHist'), chk.LambdaHist = src.LambdaHist; end
if isprop(src, 'U_Hist'), chk.U_Hist = src.U_Hist; end
if isprop(src, 'History_Time'), chk.History_Time = src.History_Time; end
if isprop(src, 'Time'), chk.Time = src.Time; end
if isprop(src, 'StepCount'), chk.StepCount = src.StepCount; end
if isprop(src, 'GlobalHistory'), chk.GlobalHistory = src.GlobalHistory; end
save(fullfile(root, 'checkpoint.mat'), '-struct', 'chk');

fprintf('[DataMgr] Appended stage %d step %d\n', stageId, evt.StepNumber);
end
