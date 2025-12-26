classdef LoadingStage < handle
    properties
        ActiveBCs    = {}; % List of Tags to enforce (e.g. {'Support', 'TipMove'})
        ActiveLoads  = {}; % List of Tags to apply (e.g. {'Pressure'})
        Duration     = 1.0;
    end
    
    methods
        function obj = LoadingStage(duration)
            obj.Duration = duration;
        end
        
        function activateBC(obj, tag),   obj.ActiveBCs{end+1} = tag; end
        function activateLoad(obj, tag), obj.ActiveLoads{end+1} = tag; end
    end
end