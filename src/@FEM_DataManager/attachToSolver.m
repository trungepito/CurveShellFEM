function attachToSolver(obj, Sol, stageIdx)
% ATTACHTOSOLVER  Wire StepConverged event to incremental writer.
% Sol      : any FEM_Solver_Nonlinear subclass
% stageIdx : integer (1-based stage index)
%
% The listener calls obj.onStepConverged(evt, stageIdx) after
% every converged Newton-Raphson increment.

% Check for StepConverged event (not a property, but an event)
try
    lh = addlistener(Sol, 'StepConverged', ...
        @(~,evt) obj.onStepConverged_(evt, stageIdx));
    obj.Listeners_{end+1} = lh;
    fprintf('[DataMgr] Listener attached to solver for stage %d.\n', stageIdx);
catch ME
    warning('[DataMgr] Failed to attach listener: %s. Incremental writing disabled for stage %d.', ...
        ME.message, stageIdx);
end

end
