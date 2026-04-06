function [Pre, Sol] = loadSnapshot(obj, mode, key)
%LOADSNAPSHOT Load persisted project snapshot.
%   [Pre, Sol] = loadSnapshot(obj)
%   [Pre, Sol] = loadSnapshot(obj, "project")
%
% Phase 1 supports project-level restore. Stage/step modes are scaffolded.

if nargin < 2 || isempty(mode)
    mode = 'project';
end
if nargin < 3
    key = [];
end

root = obj.getProjectRoot();
metaFile = fullfile(root, 'project_meta.json');

if exist(metaFile, 'file')
    switch lower(mode)
        case 'project'
            preFile = fullfile(root, 'preprocessor.mat');
            chkFile = fullfile(root, 'checkpoint.mat');
            if ~exist(preFile, 'file') || ~exist(chkFile, 'file')
                error('Snapshot files missing under %s.', root);
            end

            preData = load(preFile);
            matData = preData.Material;
            Pre = FEM_Preprocessor(matData.E, matData.nu, matData.t);
            Pre.Mesh = preData.Mesh;
            if isfield(preData, 'BCs'), Pre.BCs = preData.BCs; end
            if isfield(preData, 'Loads'), Pre.Loads = preData.Loads; end
            if isfield(preData, 'Material'), Pre.Material = preData.Material; end

            chk = load(chkFile);
            Sol = constructSolverFromCheckpoint(Pre, chk);
            fprintf('[DataMgr] Loaded snapshot from %s\n', root);
            return;

        case {'stage', 'step'}
            if strcmpi(mode, 'stage')
                if isempty(key), key = 1; end
                [Pre, Sol] = obj.restartFromStage(key);
            else
                if ~isstruct(key) || ~isfield(key, 'stageId') || ~isfield(key, 'stepId')
                    error('For mode "step", key must be struct(''stageId'',s,''stepId'',k).');
                end
                [Pre, Sol] = obj.restartFromStep(key.stageId, key.stepId);
            end
            return;
        otherwise
            error('Unknown loadSnapshot mode: %s', mode);
    end
end

% Legacy fallback
legacy = fullfile(obj.OutputFolder, [obj.ProjectName '_FullState.mat']);
if ~exist(legacy, 'file')
    error('No stage-aware snapshot or legacy state found for project "%s".', obj.ProjectName);
end

fprintf('[DataMgr] Loading legacy full state from %s...\n', legacy);
data = load(legacy);
matData = data.MaterialData;
Pre = FEM_Preprocessor(matData.E, matData.nu, matData.t);
Pre.Mesh = data.Mesh;
Pre.BCs = data.BCs;
Pre.Loads = data.Loads;
Sol = constructSolverFromCheckpoint(Pre, data);
fprintf('[DataMgr] Legacy load complete.\n');

if ~isempty(key)
    %#ok<NASGU>
end

end

function Sol = constructSolverFromCheckpoint(Pre, data)
% Construct solver object and hydrate common state fields.

if isfield(data, 'GlobalHistory') && ~isempty(data.GlobalHistory)
    if isfield(data, 'MaterialData') && isfield(data.MaterialData, 'Yield') && isfield(data.MaterialData, 'H')
        MatObj = Material_J2Plastic(data.MaterialData.E, data.MaterialData.nu, ...
            data.MaterialData.Yield, data.MaterialData.H);
        Sol = FEM_Solver_Plastic(Pre, MatObj);
    else
        Sol = FEM_Solver(Pre);
    end
    Sol.GlobalHistory = data.GlobalHistory;
else
    solverClass = '';
    if isfield(data, 'solverClass')
        solverClass = char(data.solverClass);
    end
    switch solverClass
        case 'FEM_Solver_ArcLength'
            Sol = FEM_Solver_ArcLength(Pre, SolverOptions());
        case 'FEM_Solver_Adaptive'
            Sol = FEM_Solver_Adaptive(Pre, SolverOptions());
        case 'FEM_Solver_Nonlinear'
            Sol = FEM_Solver_Nonlinear(Pre, SolverOptions());
        otherwise
            Sol = FEM_Solver(Pre);
    end
end

if isfield(data, 'U') && isprop(Sol, 'U'), Sol.U = data.U; end
if isfield(data, 'BucklingFactors') && isprop(Sol, 'BucklingFactors')
    Sol.BucklingFactors = data.BucklingFactors;
end
if isfield(data, 'LambdaHist') && isprop(Sol, 'LambdaHist'), Sol.LambdaHist = data.LambdaHist; end
if isfield(data, 'U_Hist') && isprop(Sol, 'U_Hist'), Sol.U_Hist = data.U_Hist; end
if isfield(data, 'History_Time') && isprop(Sol, 'History_Time'), Sol.History_Time = data.History_Time; end
if isfield(data, 'Time') && isprop(Sol, 'Time'), Sol.Time = data.Time; end
if isfield(data, 'StepCount') && isprop(Sol, 'StepCount'), Sol.StepCount = data.StepCount; end
end
