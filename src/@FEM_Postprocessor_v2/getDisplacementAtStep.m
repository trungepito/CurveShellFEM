function U = getDisplacementAtStep(obj, stepIdx)
% GETDISPLACEMENTATSTEP  Retrieve the displacement vector at a given step.
%
% Routes between:
%   - stepIdx = 0 / []     → use Solver.U (current live state)
%   - stepIdx = 1..nSteps  → use Solver.U_Hist(:, stepIdx)
%
% Performs bounds checking and provides a clear error message.
%
% NOTE: the all-zero check was deliberately removed.  A legitimately
% zero-displacement result (e.g. initial state, or symmetric loading) would
% be wrongly redirected to Solver.U.  The caller must ensure stepIdx is
% within [1, StepCount].
try
    nSteps = obj.Solver.StepCount; % for Non_linear solver
catch
    stepIdx=[]; % for Linear solver
end

if isempty(stepIdx) || stepIdx <= 0
    U = obj.Solver.U;
    return;
end

if stepIdx > nSteps
    error('FEM_Postprocessor:stepOutOfRange', ...
        'Requested step %d but only %d steps are stored in U_Hist.', ...
        stepIdx, nSteps);
end

U = obj.Solver.U_Hist(:, stepIdx);
end
