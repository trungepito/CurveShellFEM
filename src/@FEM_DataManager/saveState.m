function saveState(obj, Pre, Sol, options)
% options: Struct with flags (e.g., .Mesh, .Results, .History)

fprintf('[DataMgr] Saving project "%s" to %s...\n', ...
    obj.ProjectName, obj.OutputFolder);

if strcmp(obj.Format, 'MAT')
    obj.saveToMAT(Pre, Sol, options);
else
    obj.saveToCSV(Pre, Sol, options);
end
end