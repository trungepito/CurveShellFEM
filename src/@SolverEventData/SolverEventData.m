classdef SolverEventData < event.EventData
    properties
        Time          % Current Pseudo-Time
        StepNumber    % Current Step Count
        U             % Current Displacement Vector
        LoadFactor    % Current Load Multiplier (if applicable)
        Iterations    % How many iters this step took
        
        % Data decoupling (Wave 2)
        PlasticHistory % cell {nElems x 1} of HistoryData snapshots
        ReactionData   % struct with .dofs and .values
        ArcLengthUsed  % ds used in this step
    end
    
    methods
        function data = SolverEventData(t, step, u, lambda, iters, plastic, reaction, ds)
            data.Time = t;
            data.StepNumber = step;
            data.U = u;
            data.LoadFactor = lambda;
            data.Iterations = iters;
            data.PlasticHistory = plastic;
            data.ReactionData   = reaction;
            data.ArcLengthUsed  = ds;
        end
    end
end