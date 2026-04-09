function initProject(obj, Pre)
% INITPROJECT  Write preprocessor snapshot and create meta file.
% Call once before the first solve.  Safe to call again — it will
% skip writing if the project already exists (restart scenario).
obj.ensureDir_(obj.ProjectRoot_);
obj.ensureDir_(fullfile(obj.ProjectRoot_, 'stages'));

metaFile = obj.metaPath_();
if exist(metaFile, 'file')
    fprintf('[DataMgr] Project "%s" already exists. Skipping initProject.\n', ...
        obj.ProjectName);
    fprintf('[DataMgr] Use listRestartPoints() to inspect existing stages.\n');
    return;
end

% --- Write preprocessor ---
preFile = fullfile(obj.ProjectRoot_, 'preprocessor.mat');
fprintf('[DataMgr] Writing preprocessor to %s ...\n', preFile);
PreData = obj.packPreprocessor_(Pre);
save(preFile, '-struct', 'PreData', '-v7.3');

% --- Write initial project meta ---
meta = struct();
meta.project_name   = obj.ProjectName;
meta.format_version = '2.0';
meta.created        = datetime("now","Format","dd-MMM-uuuu HH:mm:ss");
meta.matlab_version = version;
meta.nStages        = 0;
meta.stages         = struct([]);
meta.status         = 'initialized';
obj.writeMeta_(meta);

fprintf('[DataMgr] Project initialized at %s\n', obj.ProjectRoot_);
end
