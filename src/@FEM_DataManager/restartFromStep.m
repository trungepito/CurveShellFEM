function [Pre, Sol] = restartFromStep(obj, stageId, stepId)
%RESTARTFROMSTEP Restart solver state from a specific stage + step.

if nargin < 2 || isempty(stageId)
    stageId = 1;
end
if nargin < 3 || isempty(stepId)
    error('restartFromStep requires stepId.');
end

[Pre, Sol] = obj.loadSnapshot('project');

root = obj.getProjectRoot();
stageDir = fullfile(root, 'stages', sprintf('stage_%03d', stageId));
stepsFile = fullfile(stageDir, 'steps.mat');
gpFile = fullfile(stageDir, 'gp_history.mat');

if ~exist(stepsFile, 'file')
    error('Missing steps file: %s', stepsFile);
end

uVar = sprintf('U_step_%d', stepId);
mVar = sprintf('step_meta_%d', stepId);

data = load(stepsFile);
if ~isfield(data, uVar)
    error('Step variable %s not found in %s.', uVar, stepsFile);
end
u = data.(uVar);
Sol.U = u;

% Populate U_Hist/StepCount when available for continuity
if isprop(Sol, 'U_Hist')
    nDofs = length(u);
    Sol.U_Hist = zeros(nDofs, stepId);
    for k = 1:stepId
        ukName = sprintf('U_step_%d', k);
        if isfield(data, ukName)
            Sol.U_Hist(:, k) = data.(ukName);
        else
            Sol.U_Hist(:, k) = u;
        end
    end
end
if isprop(Sol, 'StepCount')
    Sol.StepCount = stepId;
end
if isprop(Sol, 'History_Time') && isfield(data, mVar)
    m = data.(mVar);
    if isfield(m, 'time')
        Sol.History_Time = zeros(stepId, 1);
        for k = 1:stepId
            mkName = sprintf('step_meta_%d', k);
            if isfield(data, mkName) && isfield(data.(mkName), 'time')
                Sol.History_Time(k) = data.(mkName).time;
            end
        end
        Sol.Time = m.time;
    end
end
if isprop(Sol, 'LambdaHist')
    Sol.LambdaHist = zeros(1, stepId);
    for k = 1:stepId
        mkName = sprintf('step_meta_%d', k);
        if isfield(data, mkName) && isfield(data.(mkName), 'lambda')
            Sol.LambdaHist(k) = data.(mkName).lambda;
        end
    end
end

% Restore constitutive history for tangent consistency
if exist(gpFile, 'file') && isprop(Sol, 'Elements')
    hVar = sprintf('history_step_%d', stepId);
    gp = load(gpFile);
    if isfield(gp, hVar)
        histCell = gp.(hVar);
        n = min(numel(histCell), numel(Sol.Elements));
        for e = 1:n
            if isprop(Sol.Elements{e}, 'HistoryData')
                Sol.Elements{e}.HistoryData = histCell{e};
            end
        end
    end
end

fprintf('[DataMgr] Restarted from stage %d step %d\n', stageId, stepId);
end
