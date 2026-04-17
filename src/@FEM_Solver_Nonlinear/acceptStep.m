function acceptStep(obj, u_converged, lambda, iters_used, TrialHist_trial, ...
    F_int_conv, fixed_dofs, Stage, stageIdx, accumulated, trial_ds)
% ACCEPTSTEP  Commit converged step to solver state (with side effects).
%
% Handles:
%   - commitHistory(TrialHist)
%   - state.appendStep() for persistent history
%   - Event notification (StepConverged)
%   - Plastic snapshot recovery (if applicable)

plasticSnap = [];
if obj.hasMaterialPlastic()
    plasticSnap = cell(size(obj.Elements));
    for e = 1:length(obj.Elements)
        sctr = obj.SctrMap(e, :);
        u_el = u_converged(sctr);
        obj.Elements{e}.recoverGaussPointData(u_el);
        plasticSnap{e} = obj.Elements{e}.HistoryData;
    end
end

% Commit trial history to internal state (Gaussian point data, etc.)
obj.commitHistory(TrialHist_trial);

% Reaction vector
reaction_struct = [];
if ~isempty(F_int_conv)
    reaction_struct = struct('dofs', fixed_dofs, 'values', F_int_conv(fixed_dofs));
end

% Archive to SolutionState (primary persistent history store)
obj.state.appendStep(u_converged, lambda, plasticSnap, reaction_struct, trial_ds);

% Event notification for all listeners (DataManager, etc.)
evtData = SolverEventData(obj.Time + accumulated, ...
    obj.StepCount, u_converged, lambda, iters_used, ...
    plasticSnap, reaction_struct, trial_ds);
notify(obj, 'StepConverged', evtData);

end
