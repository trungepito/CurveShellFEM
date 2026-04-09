function commitHistory(obj, TrialHist)
% COMMITHISTORY - Finalizes the plastic state for the current increment.
if isempty(TrialHist), return; end
for e = 1:length(obj.Elements)
    % Check if element has HistoryData property (Phase 10)
    if isprop(obj.Elements{e}, 'HistoryData')
        obj.Elements{e}.HistoryData = TrialHist{e};
    end
end
end