function gpData = loadGPHistory(obj, stageIdx, stepK)
% LOADGPHISTORY  Load plastic GP HistoryData at a specific step.
% Returns cell array {nElems x 1} matching Solver.Elements layout.
gpFile = fullfile(obj.stagePath_(stageIdx), 'gp_history.mat');
if ~exist(gpFile, 'file')
    gpData = {};
    return;
end
varName = sprintf('gp_step_%05d', stepK);
tmp = load(gpFile, varName);
if ~isfield(tmp, varName)
    warning('[DataMgr] No GP history at stage %d step %d.', ...
        stageIdx, stepK);
    gpData = {};
    return;
end
gpData = tmp.(varName);
end
