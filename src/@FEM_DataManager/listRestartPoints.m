function info = listRestartPoints(obj)
% LISTRESTARTPOINTS  Return struct array of available restart points.
% Reads only project_meta.json — no MAT loading.
%
% Returns struct array with fields:
%   .stage      stage index
%   .nSteps     converged steps recorded
%   .lambda_last last load factor
%   .status     'complete' | 'in_progress' | 'interrupted'
metaFile = obj.metaPath_();
if ~exist(metaFile, 'file')
    error('[DataMgr] Project "%s" not found at %s', ...
        obj.ProjectName, obj.ProjectRoot_);
end
meta = obj.readMeta_();
if isempty(meta.stages) || meta.nStages == 0
    info = struct([]);
    fprintf('[DataMgr] No stages recorded yet.\n');
    return;
end
info = meta.stages;
fprintf('[DataMgr] %d stage(s) found:\n', length(info));
for k = 1:length(info)
    fprintf('  Stage %d: %d steps, lambda=%.4g, status=%s\n', ...
        info(k).index, info(k).nSteps, info(k).lambda_last, info(k).status);
end
end
