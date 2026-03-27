classdef LoadingStage < handle
    properties
        ActiveBCs    = {}; % List of Tags to enforce (e.g. {'Support', 'TipMove'})
        ActiveLoads  = {}; % List of Tags to apply (e.g. {'Pressure'})
        Duration     = 1.0;
        
        % Arc Length Parameters (for ArcLength solver)
        ArcLengthRadius = 0.01;    % Initial arc length radius
        ArcLengthMin = 1e-6;       % Minimum arc length
        ArcLengthMax = 1.0       % Adaptive cap for the radius
        ArcLengthPsi = 1.0       % Load-scaling factor for generalized arc-length
        ConstraintType = 'Riks'  % 'Riks' | 'LoadControl' | 'DispControl'
        ControlDOF = [];           % For DispControl: DOF index to control
    end
    
    methods
        function obj = LoadingStage(duration)
            obj.Duration = duration;
        end
        
        function activateBC(obj, tag),   obj.ActiveBCs{end+1} = tag; end
        function activateLoad(obj, tag), obj.ActiveLoads{end+1} = tag; end
    end
end