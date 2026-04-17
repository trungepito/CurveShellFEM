function U = getDisplacementAtStep(obj, stepIdx)
% GETDISPLACEMENTATSTEP  Retrieve the displacement vector at a given step.
% Performs bounds checking and provides a clear error message.

nSteps = obj.Snapshot.StepCount;

if isempty(stepIdx) || stepIdx <= 0
    % For postprocessor, "current" is the last step in the snapshot
    if nSteps == 0
        error('FEM_Postprocessor_v2:noData', 'Snapshot contains no steps.');
    end
    U = obj.Snapshot.getU(nSteps);
    return;
end

if stepIdx > nSteps
    error('FEM_Postprocessor_v2:stepOutOfRange', ...
        'Requested step %d but only %d steps are in the snapshot.', ...
        stepIdx, nSteps);
end

U = obj.Snapshot.getU(stepIdx);
end
