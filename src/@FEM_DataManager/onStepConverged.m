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

% Optional per-step constitutive history archive for post/restart (Phase 4)
if isprop(src, 'Elements') && ~isempty(src.Elements)
    stageDir = fullfile(root, 'stages', sprintf('stage_%03d', stageId));
    if ~exist(stageDir, 'dir')
        mkdir(stageDir);
    end
    h = cell(numel(src.Elements), 1);
    for e = 1:numel(src.Elements)
        if isprop(src.Elements{e}, 'HistoryData')
            h{e} = src.Elements{e}.HistoryData;
        else
            h{e} = [];
        end
    end
    hVar = sprintf('history_step_%d', evt.StepNumber);
    gpStruct = struct();
    gpStruct.(hVar) = h;
    gpFile = fullfile(stageDir, 'gp_history.mat');
    if exist(gpFile, 'file')
        save(gpFile, '-struct', 'gpStruct', '-append');
    else
        save(gpFile, '-struct', 'gpStruct');
    end
end

fprintf('[DataMgr] Appended stage %d step %d\n', stageId, evt.StepNumber);
end
