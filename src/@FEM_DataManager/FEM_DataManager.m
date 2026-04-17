classdef FEM_DataManager < handle
% FEM_DATAMANAGER  Persistent storage, incremental checkpointing, and restart.
%
% Manages a structured project directory that accumulates solver output
% incrementally as a nonlinear analysis runs.  A crash or early stop never
% loses more than CheckpointInterval steps.
%
% Directory layout
% ----------------
%   <OutputFolder>/<ProjectName>/
%   ├── project_meta.json        updated after every converged step
%   ├── preprocessor.mat         written once by initProject()
%   ├── element_cache.mat        optional; saves element-object rebuild time
%   └── stages/
%       ├── stage_01/
%       │   ├── stage_meta.json  constraint type, arc parameters, duration
%       │   ├── steps.mat        U_Hist columns + λ + scalars, appended per step
%       │   ├── gp_history.mat   plastic GP HistoryData, appended per step
%       │   └── checkpoint.mat   last converged full state, overwritten every N steps
%       ├── stage_02/
%       │   └── ...
%       └── stage_k/ (incomplete if analysis was interrupted here)
%
% Typical usage
% -------------
%   DM  = FEM_DataManager('MyProject', 'Results');
%   DM.initProject(Pre);
%
%   S1 = LoadingStage(1.0); S1.activateBC('Support'); S1.activateLoad('Pressure');
%   DM.initStage(1, S1);
%   DM.attachToSolver(Sol, 1);   % wires StepConverged listener
%   Sol.solve({S1});
%
%   % Restart after crash
%   [Pre2, Sol2] = DM.restartFromCheckpoint(2);
%
% See also: FEM_Solver_Nonlinear, FEM_Postprocessor_v2

    % ====================================================================
    properties
        ProjectName         % string: base name used for all files
        OutputFolder        % string: root directory (created if absent)
        Format = 'MAT'      % 'MAT' only for now; CSV kept for legacy flat saves

        % Incremental write settings
        CheckpointInterval = 5   % write checkpoint.mat every N converged steps
        SaveGPHistory      = true % write plastic GP history to gp_history.mat
    end

    % ====================================================================
    properties (Access = private)
        ProjectRoot_   % full path: OutputFolder/ProjectName
        Listeners_     % cell of listener handles (kept so they can be deleted)
        StepCounters_  % containers.Map: stage index -> step count within stage
    end

    % ====================================================================
    methods
        % ------------------------------------------------------------------
        function obj = FEM_DataManager(name, folder, format)
            % FEM_DataManager(name, folder, format)
            % name   : project name string
            % folder : output root directory (default: 'Results')
            % format : 'MAT' (default) or 'CSV' (legacy flat only)
            obj.ProjectName = name;
            if nargin < 2 || isempty(folder), folder = 'Results'; end
            if nargin < 3 || isempty(format), format = 'MAT'; end
            obj.OutputFolder = folder;
            obj.Format       = upper(format);
            obj.ProjectRoot_ = fullfile(folder, name);
            obj.Listeners_   = {};
            obj.StepCounters_ = containers.Map('KeyType','int32','ValueType','int32');
        end

        % ------------------------------------------------------------------
        delete(obj)
    end

    % ====================================================================
    % PUBLIC: PROJECT LIFECYCLE
    % ====================================================================
    methods
        initProject(obj, Pre)
        initStage(obj, stageIdx, Stage)
        attachToSolver(obj, Sol, stageIdx)
        finalizeStage(obj, stageIdx, lambda_final)
        finalizeProject(obj)
    end
    % ====================================================================
    % PUBLIC: MANUAL SAVE (replaces old saveState / saveToMAT)
    % ====================================================================
    methods
        saveSnapshot(obj, Pre, Sol, opts)
        [Pre, Sol] = loadSnapshot(obj)
    end
    % ====================================================================
    % PUBLIC: RESTART API
    % ====================================================================
    methods
        info = listRestartPoints(obj)
        [Pre, Sol] = restartFromCheckpoint(obj, stageIdx)
        [Pre, Sol] = restartFromStep(obj, stageIdx, stepK)
        [Pre, Sol] = restartFromStage(obj, stageIdx)
    end
    % ====================================================================
    % PUBLIC: QUERY / POST-PROCESSING HELPERS
    % ====================================================================
    methods
        U = loadStepU(obj, stageIdx, stepK)
        [U_hist, lambda_hist] = loadStageHistory(obj, stageIdx)
        gpData = loadGPHistory(obj, stageIdx, stepK)
        appendStep(obj, stageIdx, stepData)
    end
    % Legacy method!!!, can be deleted!!
    methods
        saveState(obj, Pre, Sol, options)
        [Pre, Sol] = loadState(obj)
    end
    
    methods (Static)
        isValid = validatePreprocessorOutput(Pre)
    end
    % ====================================================================
    % PRIVATE: EVENT HANDLER
    % ====================================================================
    methods (Access = public)
        onStepConverged_(obj, evt, stageIdx)
    end
    
    methods (Access = private)
        onLinear_solu(obj,evt,Sol)
    end
    % ====================================================================
    % PRIVATE: DISK I/O HELPERS
    % ====================================================================
    methods (Access = private)
        writeStep_(obj, stageIdx, stepData)
        writeCheckpoint_(obj, stageIdx, stepData, stepN)
        sd = loadSingleStep_(~, stepsFile, stepK)
        Sol = loadStepsIntoSolver_(obj, Sol, stepsFile, upToStep)
        Sol = reconstructSolver_(~, Pre, chk)
        PreData = packPreprocessor_(~, Pre)
        Pre = loadPreprocessor_(obj)
        p = stagePath_(obj, stageIdx)
        p = metaPath_(obj)
        ensureDir_(~, d)
        tf = matHasVar_(~, matFile, varName)
        meta = readMeta_(obj)
        writeMeta_(obj, meta)
        s = readJSON_(~, filepath)
        writeJSON_(~, filepath, s)
        % legacy can be deleted!
        saveToMAT(obj, Pre, Sol, opt)
        saveToCSV(obj, Pre, Sol, opt)
    end
end
