function sd = loadSingleStep_(~, stepsFile, stepK)
varName = sprintf('step_%05d', stepK);
if ~exist(stepsFile, 'file')
    error('[DataMgr] steps.mat not found: %s', stepsFile);
end
% Steps are stored inside the 'steps' struct field
tmp = load(stepsFile, 'steps');
if ~isfield(tmp, 'steps') || ~isfield(tmp.steps, varName)
    error('[DataMgr] Step %d not found in %s', stepK, stepsFile);
end
sd = tmp.steps.(varName);
end
