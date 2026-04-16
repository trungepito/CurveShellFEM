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
% the HistoryData that was committed at stepIdx, not the current one.
% ---------------------------------------------------------------
nElems = size(obj.Model.Mesh.Elements, 1);
hasState = isprop(obj.Solver, 'state') && ~isempty(obj.Solver.state);

% ---------------------------------------------------------------
% Main loop
% ---------------------------------------------------------------
gpCell = cell(nElems, 1);

for e = 1:nElems
    sctr  = obj.Solver.SctrMap(e, :);   % 48 global DOF indices
    u_el  = U(sctr);                    % 48x1 element DOF vector
    elObj = obj.Solver.Elements{e};
    
    archiveFound = false;
    if ~isempty(stepIdx) && stepIdx > 0 && hasState
        if stepIdx <= obj.Solver.state.StepCount && ...
           length(obj.Solver.state.PlasticHistoryArchive) >= stepIdx && ...
           ~isempty(obj.Solver.state.PlasticHistoryArchive{stepIdx})
           
           % Use archived plastic state
            savedHD = elObj.HistoryData;
            elObj.HistoryData = obj.Solver.state.PlasticHistoryArchive{stepIdx}{e};
            gpCell{e} = elObj.recoverGaussPointData(u_el);
            elObj.HistoryData = savedHD;
            archiveFound = true;
        end
    end

    if ~archiveFound
        % Fallback for current step (live recovery) or missing archive
        % recoverGaussPointData will use live HistoryData if present.
        gpCell{e} = elObj.recoverGaussPointData(u_el);
    end
end

% ---------------------------------------------------------------
% Update cache
% ---------------------------------------------------------------
obj.CachedStep = stepIdx;
obj.CachedGP   = gpCell;
end
