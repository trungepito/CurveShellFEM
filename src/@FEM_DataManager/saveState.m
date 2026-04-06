function saveState(obj, Pre, Sol, options)
% options: Struct with flags (e.g., .Mesh, .Results, .History)

fprintf('[DataMgr] Saving project "%s" to %s...\n', ...
    obj.ProjectName, obj.OutputFolder);
obj.saveSnapshot(Pre, Sol, options);
end
