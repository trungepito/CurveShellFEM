classdef SolverLinearEventData < event.EventData
    properties
        U             % Current Displacement Vector
        LoadFactor    % Current Load Multiplier (if applicable)
    end
    
    methods
        function data = SolverLinearEventData( u, loadfactor)
            if nargin==1
            data.U = u;
            data.LoadFactor = [];
            else
                data.U = u;
                data.LoadFactor = loadfactor;
            end
        end
    end
end