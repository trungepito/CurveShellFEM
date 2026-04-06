function saveSnapshot(obj, Pre, Sol, options)
%SAVESNAPSHOT Phase-1 drop-in project snapshot writer.
% Persists project metadata + immutable preprocessor data + latest checkpoint.

if nargin < 4 || isempty(options)
    options = struct();
end

defaults = struct('saveMesh', true, 'saveBCs', true, ...
                  'saveResults', true, 'saveHistory', true);
fn = fieldnames(defaults);
for i = 1:numel(fn)
    if ~isfield(options, fn{i})
        options.(fn{i}) = defaults.(fn{i});
    end
end

obj.initProject(Pre, Sol, options);
root = obj.getProjectRoot();

% 1) Save preprocessor snapshot (immutable baseline)
preData = struct();
if options.saveMesh
    preData.Mesh = Pre.Mesh;
    preData.Material = Pre.Material;
end
if options.saveBCs
    preData.BCs = Pre.BCs;
    preData.Loads = Pre.Loads;
end
save(fullfile(root, 'preprocessor.mat'), '-struct', 'preData');

% 2) Save current checkpoint (restart anchor)
chk = struct();
chk.solverClass = class(Sol);
chk.savedAt = datestr(now, 30);
if options.saveResults
    chk.U = Sol.U;
    if isprop(Sol, 'LambdaHist'), chk.LambdaHist = Sol.LambdaHist; end
    if isprop(Sol, 'U_Hist'), chk.U_Hist = Sol.U_Hist; end
    if isprop(Sol, 'History_Time'), chk.History_Time = Sol.History_Time; end
    if isprop(Sol, 'Time'), chk.Time = Sol.Time; end
    if isprop(Sol, 'StepCount'), chk.StepCount = Sol.StepCount; end
    if isprop(Sol, 'BucklingFactors'), chk.BucklingFactors = Sol.BucklingFactors; end
end
if options.saveHistory && isprop(Sol, 'GlobalHistory')
    chk.GlobalHistory = Sol.GlobalHistory;
end
save(fullfile(root, 'checkpoint.mat'), '-struct', 'chk');

% 3) Backward-compatible legacy full state output
if strcmp(obj.Format, 'MAT')
    obj.saveToMAT(Pre, Sol, options);
else
    obj.saveToCSV(Pre, Sol, options);
end

% 4) Update project metadata timestamp + stage count hint
metaFile = fullfile(root, 'project_meta.json');
if exist(metaFile, 'file')
    meta = jsondecode(fileread(metaFile));
    meta.updatedAt = datestr(now, 30);
    if isprop(Sol, 'StepCount')
        meta.lastStepCount = Sol.StepCount;
    end
    tmpFile = [metaFile '.tmp'];
    fid = fopen(tmpFile, 'w');
    fwrite(fid, jsonencode(meta), 'char');
    fclose(fid);
    movefile(tmpFile, metaFile, 'f');
end

fprintf('[DataMgr] Snapshot saved to %s\n', root);
end
