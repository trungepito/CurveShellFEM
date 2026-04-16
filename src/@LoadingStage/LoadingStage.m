classdef LoadingStage < handle
    properties
        ActiveBCs    = {}; % List of Tags to enforce (e.g. {'Support', 'TipMove'})
        ActiveLoads  = {}; % List of Tags to apply (e.g. {'Pressure'})
        Duration     = 1.0;
        TargetLambda = Inf; % stop when lambda reaches this value
        
        % New: strategy object (preferred)
        strategy     = []  % IncrementalStrategy instance or []
        
        % Arc Length Parameters (legacy — auto-construct strategy if set)
        ArcLengthRadius = 0.01;    % Initial arc length radius
        ArcLengthMin = 1e-6;       % Minimum arc length
        ArcLengthMax = 1.0;        % Adaptive cap for the radius
        ArcLengthPsi = 1.0;        % Load-scaling factor for generalized arc-length
        ConstraintType = 'Riks';   % 'Riks' | 'LoadControl' | 'DispControl' (deprecated: use strategy)
        ControlDOF = [];           % For DispControl: DOF index to control
    end
    
    methods
        function obj = LoadingStage(duration)
            if nargin > 0, obj.Duration = duration; end
        end
        
        function activateBC(obj, tag),   obj.ActiveBCs{end+1} = tag; end
        function activateLoad(obj, tag), obj.ActiveLoads{end+1} = tag; end
        
        function s = getStrategy(obj)
        % GETSTRATEGY  Return the active strategy, constructing from legacy props if needed.
            if ~isempty(obj.strategy)
                s = obj.strategy;
                return;
            end
            if isempty(obj.ConstraintType)
                % Default to Riks
                s = RiksStrategy('ArcLengthRadius', obj.ArcLengthRadius, ...
                    'ArcLengthMin', obj.ArcLengthMin, 'ArcLengthMax', obj.ArcLengthMax, ...
                    'Psi', obj.ArcLengthPsi);
                return;
            end
            switch obj.ConstraintType
                case 'Riks'
                    s = RiksStrategy('ArcLengthRadius', obj.ArcLengthRadius, ...
                        'ArcLengthMin', obj.ArcLengthMin, 'ArcLengthMax', obj.ArcLengthMax, ...
                        'Psi', obj.ArcLengthPsi);
                case 'LoadControl'
                    s = LoadControlStrategy('ArcLengthRadius', obj.ArcLengthRadius, ...
                        'ArcLengthMin', obj.ArcLengthMin, 'ArcLengthMax', obj.ArcLengthMax);
                case 'DispControl'
                    if isempty(obj.ControlDOF)
                        error('LoadingStage:noControlDOF', ...
                            'Set ControlDOF before using DispControl');
                    end
                    s = DispControlStrategy(obj.ControlDOF, ...
                        'ArcLengthRadius', obj.ArcLengthRadius, ...
                        'ArcLengthMin', obj.ArcLengthMin, 'ArcLengthMax', obj.ArcLengthMax);
                otherwise
                    warning('LoadingStage:unknownConstraint', ...
                        'Unknown ConstraintType ''%s'', defaulting to Riks', obj.ConstraintType);
                    s = RiksStrategy('ArcLengthRadius', obj.ArcLengthRadius);
            end
        end
    end
end