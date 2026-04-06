function setHistorySource(obj, gpHistoryFile)
%SETHISTORYSOURCE Configure optional gp_history.mat source for Step recovery.

if nargin < 2 || isempty(gpHistoryFile)
    obj.UseStoredGPHistory = false;
    obj.GPHistoryFile = '';
    return;
end

if ~exist(gpHistoryFile, 'file')
    warning('FEM_Postprocessor_v2:HistoryFileMissing', ...
        'History file not found: %s. Falling back to live element data.', gpHistoryFile);
    obj.UseStoredGPHistory = false;
    obj.GPHistoryFile = '';
    return;
end

obj.GPHistoryFile = gpHistoryFile;
obj.UseStoredGPHistory = true;
obj.CachedStep = -1;
obj.CachedGP = {};
end
