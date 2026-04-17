function sd = loadSingleStep_(~, stepsFile, stepK)
varName = sprintf('step_%05d', stepK);
if ~exist(stepsFile, 'file')
    error('[DataMgr] steps.mat not found: %s', stepsFile);
end
% Steps are stored as top-level variables (step_00001, etc.)
tmp = load(stepsFile, varName);
if ~isfield(tmp, varName)
    error('[DataMgr] Step %d not found in %s', stepK, stepsFile);
end
sd = tmp.(varName);
end
