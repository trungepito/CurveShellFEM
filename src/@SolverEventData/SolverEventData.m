classdef SolverEventData < event.EventData
    properties
        Time          % Current Pseudo-Time
        StepNumber    % Current Step Count
        U             % Current Displacement Vector
        LoadFactor    % Current Load Multiplier (if applicable)
        Iterations    % How many iters this step took
    end
    
    methods
        function data = SolverEventData(t, step, u, lambda, iters)
            data.Time = t;
            data.StepNumber = step;
            data.U = u;
            data.LoadFactor = lambda;
            data.Iterations = iters;
        end
    end
end