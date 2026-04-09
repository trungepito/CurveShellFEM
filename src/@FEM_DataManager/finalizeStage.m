function finalizeStage(obj, stageIdx, lambda_final)
% FINALIZESTAGE  Mark a stage as complete in the meta files.
% Call after Sol.solve() returns successfully.
if nargin < 3, lambda_final = NaN; end
stageDir  = obj.stagePath_(stageIdx);
smFile    = fullfile(stageDir, 'stage_meta.json');
if ~exist(smFile, 'file'), return; end
sm = obj.readJSON_(smFile);
sm.status       = 'complete';
sm.finished     = datetime("now","Format","dd-MMM-uuuu HH:mm:ss");
sm.lambda_last  = lambda_final;
obj.writeJSON_(smFile, sm);

meta = obj.readMeta_();
if length(meta.stages) >= stageIdx
    meta.stages(stageIdx).status      = 'complete';
    meta.stages(stageIdx).lambda_last = lambda_final;
    if obj.StepCounters_.isKey(int32(stageIdx))
        meta.stages(stageIdx).nSteps = ...
            obj.StepCounters_(int32(stageIdx));
    end
end
obj.writeMeta_(meta);
fprintf('[DataMgr] Stage %d finalized. lambda_final = %.6g\n', ...
    stageIdx, lambda_final);
end
