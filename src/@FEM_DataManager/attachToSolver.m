function attachToSolver(obj, Sol, stageId)
%ATTACHTOSOLVER Register StepConverged listener for incremental persistence.

if nargin < 3 || isempty(stageId)
    stageId = 1;
end

if isempty(Sol)
    error('attachToSolver requires a valid solver object.');
end

if ~isprop(Sol, 'Model')
    warning('[DataMgr] Solver does not expose expected Model property. Listener not attached.');
    return;
end

obj.initProject(Sol.Model, Sol, struct());

listener = addlistener(Sol, 'StepConverged', @(src, evt) obj.onStepConverged(src, evt, stageId));
obj.ListenerHandles{end+1} = listener;

fprintf('[DataMgr] Attached StepConverged listener to %s (stage %d).\n', class(Sol), stageId);
end
