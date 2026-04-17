function onStepConverged_(obj, evt, stageIdx)
% Called by addlistener after every converged step.
% evt : SolverEventData (Time, StepNumber, U, LoadFactor, Iterations, PlasticHistory, ReactionData, ArcLengthUsed)

fprintf('[Debug] onStepConverged_ start\n');
stepData.U          = evt.U;
stepData.lambda     = evt.LoadFactor;
stepData.iters      = evt.Iterations;
stepData.time       = evt.Time;
stepData.arc_used   = evt.ArcLengthUsed;
stepData.GPHistory  = evt.PlasticHistory;
stepData.reaction   = evt.ReactionData;

fprintf('[Debug] calling writeStep_\n');
obj.writeStep_(stageIdx, stepData);
fprintf('[Debug] onStepConverged_ end\n');
end
