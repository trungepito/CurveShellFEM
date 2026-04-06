function appendStep(obj, stageId, stepPayload)
%APPENDSTEP Append one converged step payload into stage steps.mat.
%
% Saves two variables per step:
%   - U_step_k
%   - step_meta_k

if nargin < 2 || isempty(stageId)
    stageId = 1;
end
if nargin < 3 || isempty(stepPayload)
    error('appendStep requires a non-empty stepPayload.');
end
if ~isfield(stepPayload, 'step') || isempty(stepPayload.step)
    error('stepPayload.step is required.');
end
if ~isfield(stepPayload, 'U')
    error('stepPayload.U is required.');
end

root = obj.getProjectRoot();
if ~exist(fullfile(root, 'project_meta.json'), 'file')
    obj.initProject([], [], struct());
end

stageDir = fullfile(root, 'stages', sprintf('stage_%03d', stageId));
if ~exist(stageDir, 'dir')
    mkdir(stageDir);
end

k = stepPayload.step;
stepVarName = sprintf('U_step_%d', k);
metaVarName = sprintf('step_meta_%d', k);

metaPayload = rmfield_if_exists(stepPayload, 'U');
metaPayload.savedAt = datestr(now, 30);

saveStruct = struct();
saveStruct.(stepVarName) = stepPayload.U;
saveStruct.(metaVarName) = metaPayload;

stepsFile = fullfile(stageDir, 'steps.mat');
if exist(stepsFile, 'file')
    save(stepsFile, '-struct', 'saveStruct', '-append');
else
    save(stepsFile, '-struct', 'saveStruct');
end

metaFile = fullfile(stageDir, 'stage_meta.json');
stageMeta = readOrDefaultStageMeta(metaFile, stageId);
stageMeta.lastStep = max(stageMeta.lastStep, k);
stageMeta.nSteps = max(stageMeta.nSteps, k);
stageMeta.updatedAt = datestr(now, 30);
writeJsonAtomic(metaFile, stageMeta);

projectMetaFile = fullfile(root, 'project_meta.json');
if exist(projectMetaFile, 'file')
    pm = jsondecode(fileread(projectMetaFile));
    pm.updatedAt = datestr(now, 30);
    if ~isfield(pm, 'nStages') || stageId > pm.nStages
        pm.nStages = stageId;
    end
    writeJsonAtomic(projectMetaFile, pm);
end
end

function S = readOrDefaultStageMeta(metaFile, stageId)
if exist(metaFile, 'file')
    S = jsondecode(fileread(metaFile));
    return;
end
S = struct();
S.stageId = stageId;
S.status = 'in_progress';
S.nSteps = 0;
S.lastStep = 0;
S.createdAt = datestr(now, 30);
S.updatedAt = S.createdAt;
end

function writeJsonAtomic(path, payload)
tmp = [path '.tmp'];
fid = fopen(tmp, 'w');
if fid < 0
    error('Could not open %s for writing.', tmp);
end
fwrite(fid, jsonencode(payload), 'char');
fclose(fid);
movefile(tmp, path, 'f');
end

function out = rmfield_if_exists(in, fieldName)
out = in;
if isfield(out, fieldName)
    out = rmfield(out, fieldName);
end
end
