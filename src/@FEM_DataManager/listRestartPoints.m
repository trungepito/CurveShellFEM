function points = listRestartPoints(obj)
%LISTRESTARTPOINTS Enumerate known restart anchors.

points = struct('id', {}, 'mode', {}, 'path', {}, 'exists', {});
root = obj.getProjectRoot();

metaFile = fullfile(root, 'project_meta.json');
chkFile = fullfile(root, 'checkpoint.mat');
legacyFile = fullfile(obj.OutputFolder, [obj.ProjectName '_FullState.mat']);

if exist(metaFile, 'file')
    points(end+1) = struct( ...
        'id', 'project-latest', ...
        'mode', 'project', ...
        'path', chkFile, ...
        'exists', exist(chkFile, 'file') == 2); %#ok<AGROW>
end

stagesDir = fullfile(root, 'stages');
if exist(stagesDir, 'dir')
    d = dir(fullfile(stagesDir, 'stage_*'));
    d = d([d.isdir]);
    for i = 1:numel(d)
        stagePath = fullfile(stagesDir, d(i).name);
        stepsPath = fullfile(stagePath, 'steps.mat');
        metaPath = fullfile(stagePath, 'stage_meta.json');
        stageId = i;
        if exist(metaPath, 'file')
            s = jsondecode(fileread(metaPath));
            if isfield(s, 'stageId'), stageId = s.stageId; end
        end
        points(end+1) = struct( ... %#ok<AGROW>
            'id', sprintf('stage-%03d-latest', stageId), ...
            'mode', 'stage', ...
            'path', stepsPath, ...
            'exists', exist(stepsPath, 'file') == 2);
    end
end

if exist(legacyFile, 'file')
    points(end+1) = struct( ...
        'id', 'legacy-fullstate', ...
        'mode', 'project', ...
        'path', legacyFile, ...
        'exists', true); %#ok<AGROW>
end
end
