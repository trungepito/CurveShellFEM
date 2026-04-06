function initProject(obj, Pre, Sol, options)
%INITPROJECT Initialize stage-aware persistence folder + project metadata.
%
% Phase 1 (foundation): creates project root, stages folder and baseline
% metadata. No solver behavior changes required.

if nargin < 4 || isempty(options)
    options = struct();
end

root = obj.getProjectRoot();
stagesDir = fullfile(root, 'stages');

if ~exist(root, 'dir')
    mkdir(root);
end
if ~exist(stagesDir, 'dir')
    mkdir(stagesDir);
end

metaFile = fullfile(root, 'project_meta.json');
if exist(metaFile, 'file')
    return;
end

meta = struct();
meta.format = 'CurveShellFEM-DataManager';
meta.version = '1.0.0';
meta.projectName = obj.ProjectName;
meta.createdAt = datestr(now, 30);
meta.updatedAt = meta.createdAt;
meta.nStages = 0;
meta.storage = struct('preprocessor', 'preprocessor.mat', ...
                      'checkpoint', 'checkpoint.mat', ...
                      'stagesDir', 'stages');

if nargin >= 2 && ~isempty(Pre)
    if (isstruct(Pre) && isfield(Pre, 'Mesh')) || isprop(Pre, 'Mesh')
        meta.mesh = struct();
        meta.mesh.nNodes = size(Pre.Mesh.Nodes, 1);
        meta.mesh.nElements = size(Pre.Mesh.Elements, 1);
    end
end

if nargin >= 3 && ~isempty(Sol)
    meta.solverClass = class(Sol);
else
    meta.solverClass = '';
end

tmpFile = [metaFile '.tmp'];
fid = fopen(tmpFile, 'w');
if fid < 0
    error('Could not open %s for writing.', tmpFile);
end
fwrite(fid, jsonencode(meta), 'char');
fclose(fid);
movefile(tmpFile, metaFile, 'f');
end
