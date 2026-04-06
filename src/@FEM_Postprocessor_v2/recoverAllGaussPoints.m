function gpCell = recoverAllGaussPoints(obj, stepIdx)
% RECOVERALLGAUSSPOINTS  Stage 1: element-local Gauss-point recovery.
%
% Loops over every element, extracts the 48-DOF displacement vector from
% the solution history, and delegates to Curve8Element.recoverGaussPointData.
%
% For plastic elements the GP data is read straight from HistoryData that
% was committed at the converged step — no recomputation.  For elastic
% elements the kinematics are replayed, including the Green-Lagrange
% A_geom correction.
%
% Result is cached: if stepIdx matches obj.CachedStep the stored cell
% array is returned immediately without looping.
%
% Input:
%   stepIdx  Column index into Solver.U_Hist (1-based).
%            Pass 0 or [] to use the current Solver.U.
%
% Output:
%   gpCell  {nElems x 1} cell array, each cell a [20x1] gpData struct array.

% ---------------------------------------------------------------
% Cache check
% ---------------------------------------------------------------
if ~isempty(stepIdx) && stepIdx > 0 && stepIdx == obj.CachedStep
    gpCell = obj.CachedGP;
    return;
end

% ---------------------------------------------------------------
% Retrieve displacement vector
% ---------------------------------------------------------------
U = obj.getDisplacementAtStep(stepIdx);

% ---------------------------------------------------------------
% Plastic-element history: for history-consistent recovery we need
% the HistoryData that was committed at stepIdx, not the current one
% (which reflects the latest converged step).
%
% Strategy:
%   - If stepIdx == current step (or 0/[]), Elements{e}.HistoryData is
%     already correct.
%   - If stepIdx < current step, we cannot recover past plastic state
%     without a history store.  We fall back to elastic re-integration
%     with the historic U, which is still kinematically consistent even
%     if the stress will be elastic.  A warning is issued once.
% ---------------------------------------------------------------
nElems    = size(obj.Model.Mesh.Elements, 1);
try
    currentStep = obj.Solver.StepCount;
catch
    currentStep=9999;
end

if ~isempty(stepIdx) && stepIdx > 0 && stepIdx < currentStep
    warning('FEM_Postprocessor:staleHistory', ...
        ['Requesting step %d but current step is %d. ' ...
         'Plastic stress recovery uses elastic re-integration ' ...
         'because past HistoryData is not stored per step. ' ...
         'Kinematic fields (displacement, strain) are exact.'], ...
        stepIdx, currentStep);
    useHistoryData = false;
else
    useHistoryData = true;
end

% ---------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------
gpCell = cell(nElems, 1);

for e = 1:nElems
    sctr  = obj.Solver.SctrMap(e, :);   % 48 global DOF indices
    u_el  = U(sctr);                    % 48x1 element DOF vector

    elObj = obj.Solver.Elements{e};

    if useHistoryData
        % Normal path: let recoverGaussPointData decide plastic vs elastic
        gpCell{e} = elObj.recoverGaussPointData(u_el);
    else
        % Historic step: temporarily blank HistoryData to force elastic path
        savedHist              = elObj.HistoryData;
        elObj.HistoryData      = [];
        gpCell{e}              = elObj.recoverGaussPointData(u_el);
        elObj.HistoryData      = savedHist;  % restore
    end
end

% ---------------------------------------------------------------
% Update cache
% ---------------------------------------------------------------
obj.CachedStep = stepIdx;
obj.CachedGP   = gpCell;
end
