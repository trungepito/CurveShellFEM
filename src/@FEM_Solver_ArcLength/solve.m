function solve(obj, StageList)
% SOLVE - Master arc-length solve loop over a list of LoadingStage objects.
%
% Overrides FEM_Solver_Adaptive.solve to route every stage through the
% arc-length corrector instead of the standard Newton bisection path.
%
% Syntax:
%   obj.solve(StageList)
%
% Inputs:
%   StageList - Cell array of LoadingStage objects. Each stage carries its
%               own arc-length parameters (ArcLengthRadius, ArcLengthMin,
%               ArcLengthMax, ConstraintType, ControlDOF).
%
% The arc-length load factor (lambda) is tracked internally.  After all
% stages are complete, obj.LambdaHist and obj.ArcLengthHistory contain the
% per-step records alongside the displacement history in obj.U_Hist.
%
% See also: solveArcLengthStage, arcLengthStep

fprintf('--- Starting Arc-Length Analysis ---\n');
fprintf('    Stages: %d  |  Constraint default: %s\n', ...
    length(StageList), obj.ConstraintType);

% Ensure history arrays start empty so the first call to solve is clean
% even if the object is reused across multiple analyses.
obj.LambdaHist       = [];
obj.ArcLengthHistory = [];
obj.U_Hist           = zeros(length(obj.U), 0);  % nDofs x 0 (grows dynamically)
obj.History_Time     = [];
obj.StepCount        = 0;
obj.Time             = 0;

for s = 1:length(StageList)
    currentStage = StageList{s};
    fprintf('\n>>> Stage %d / %d\n', s, length(StageList));

    % Apply stage-level constraint overrides if the stage supplies them
    if isprop(currentStage, 'ConstraintType') && ~isempty(currentStage.ConstraintType)
        obj.ConstraintType = currentStage.ConstraintType;
    end
    if isprop(currentStage, 'ControlDOF') && ~isempty(currentStage.ControlDOF)
        obj.ControlDOF = currentStage.ControlDOF;
    end

    % Delegate to the stage-level driver
    success = obj.solveArcLengthStage(currentStage, s);

    if ~success
        fprintf('!!! Arc-length analysis aborted at stage %d !!!\n', s);
        return;
    end
end

fprintf('\n--- Arc-Length Analysis Complete ---\n');
fprintf('    Total converged steps: %d\n', obj.StepCount);
end
