function setup_project()
% SETUP_PROJECT Adds CurveShellFEM directories to the MATLAB path
% Run this script before starting work or running examples.

fprintf('>> Configuring CurveShellFEM Path...\n');

% Get the root directory of the project
rootPath = fileparts(mfilename('fullpath'));

% Define directories to add
dirs = {
    fullfile(rootPath, 'src'), ...
    fullfile(rootPath, 'tests'), ...
    fullfile(rootPath, 'examples')
};

% Add each directory (and its subfolders for src) to path
for i = 1:length(dirs)
    if exist(dirs{i}, 'dir')
        addpath(dirs{i});
        % For src, we might want to add subfolders, but @folders are handled automatically
        % if the parent is on the path.
        fprintf('   Added: %s\n', dirs{i});
    else
        fprintf('   Warning: Directory not found: %s\n', dirs{i});
    end
end

% Save path if desired (optional, prompts user)
% savepath;

fprintf('>> Setup complete. You can now run examples (e.g., snapthrough) or tests (e.g., Patchtest).\n');

end
