function root = getProjectRoot(obj)
%GETPROJECTROOT Returns project-scoped persistence root folder.
root = fullfile(obj.OutputFolder, obj.ProjectName);
end
