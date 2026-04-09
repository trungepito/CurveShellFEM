function onStepConverged_(obj, evt, stageIdx, Sol)
% Called by addlistener after every converged step.
% evt : SolverEventData (Time, StepNumber, U, LoadFactor, Iterations)

stepData.U       = evt.U;
stepData.lambda  = evt.LoadFactor;
stepData.iters   = evt.Iterations;
stepData.time    = evt.Time;
stepData.arc_used = NaN;  % filled in if ArcLengthHistory available

if isprop(Sol, 'ArcLengthHistory') && ...
   ~isempty(Sol.ArcLengthHistory)
    stepData.arc_used = Sol.ArcLengthHistory(end);
end

% Plastic GP history (optional, can be large)
if obj.SaveGPHistory && ~isempty(Sol.Elements)
    nElems = length(Sol.Elements);
    gpCell = cell(nElems, 1);
    hasHist = false;
    for e = 1:nElems
        el = Sol.Elements{e};
        if isprop(el, 'HistoryData') && ~isempty(el.HistoryData)
            gpCell{e} = el.HistoryData;
            hasHist   = true;
        end
    end
    if hasHist
        stepData.GPHistory = gpCell;
    end
end

obj.writeStep_(stageIdx, stepData);
end
