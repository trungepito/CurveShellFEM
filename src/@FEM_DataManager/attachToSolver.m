function attachToSolver(obj, Sol, stageIdx)
% ATTACHTOSOLVER  Wire StepConverged event to incremental writer.
% Sol      : any FEM_Solver_Nonlinear subclass
% stageIdx : integer (1-based stage index)
%
% The listener calls obj.onStepConverged(evt, stageIdx) after
% every converged Newton-Raphson increment.
if ~isprop(Sol, 'StepConverged')
    warning('[DataMgr] Solver does not have StepConverged event.Incremental writing disabled for stage %d.', stageIdx);
    return;
end
lh = addlistener(Sol, 'StepConverged', ...
    @(~,evt) obj.onStepConverged_(evt, stageIdx, Sol));
obj.Listeners_{end+1} = lh;
fprintf('[DataMgr] Listener attached to solver for stage %d.\n', stageIdx);
end
