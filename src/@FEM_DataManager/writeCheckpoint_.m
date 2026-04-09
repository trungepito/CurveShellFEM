function writeCheckpoint_(obj, stageIdx, stepData, stepN)
chkFile = fullfile(obj.stagePath_(stageIdx), 'checkpoint.mat');
chk.U          = stepData.U;
chk.lambda     = stepData.lambda;
chk.step       = stepN;
chk.saved_at   = datetime("now","Format", "dd-MMM-uuuu HH:mm:ss");
if isfield(stepData,'GPHistory')
    chk.GPHistory = stepData.GPHistory;
end
save(chkFile, '-struct', 'chk', '-v7.3');
end
