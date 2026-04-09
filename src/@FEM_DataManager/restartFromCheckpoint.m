function [Pre, Sol] = restartFromCheckpoint(obj, stageIdx)
% RESTARTFROMCHECKPOINT  Reconstruct Pre and Sol from the last
% checkpoint in a given stage.
%
% The returned Sol has:
%   .U          = last converged displacement
%   .LambdaHist = all lambda values up to checkpoint
%   .U_Hist     = all U columns up to checkpoint
%   .StepCount  = number of steps already completed
%
% The caller should call Sol.solve({remaining stages}) to continue.
fprintf('[DataMgr] Restarting from stage %d checkpoint...\n', stageIdx);

% 1. Reconstructed Pre
Pre = obj.loadPreprocessor_();

% 2. Load checkpoint
chkFile = fullfile(obj.stagePath_(stageIdx), 'checkpoint.mat');
if ~exist(chkFile, 'file')
    error('[DataMgr] No checkpoint found for stage %d at %s', ...
        stageIdx, chkFile);
end
chk = load(chkFile);

% 3. Reconstructed Sol
Sol = obj.reconstructSolver_(Pre, chk);

% 4. Load accumulated step history from steps.mat
stepsFile = fullfile(obj.stagePath_(stageIdx), 'steps.mat');
if exist(stepsFile, 'file')
    Sol = obj.loadStepsIntoSolver_(Sol, stepsFile);
end

fprintf('[DataMgr] Restart ready. %d steps loaded. lambda = %.6g\n', ...
    Sol.StepCount, Sol.U(1));  % lambda stored in chk
end
