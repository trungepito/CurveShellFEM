classdef DispControlStrategy < IncrementalStrategy
% DISPCONTROLSTRATEGY  Fixed displacement increment at a specific DOF.
%
% The constraint is: u(ControlDOF) = u0(ControlDOF) + ds
% ControlDOF is specified as a GLOBAL DOF index.
%
% Usage:
%   strat = DispControlStrategy(57, 'ArcLengthRadius', 0.001);
%   % where DOF 57 = node 10, direction Z (if 6-DOF per node)

    properties
        ArcLengthRadius = 0.001
        ArcLengthMin    = 1e-8
        ArcLengthMax    = 0.1
        ControlDOF      = 0   % global DOF index to control
    end

    properties (Access = private)
        % Cached mapping from global DOF to free-DOF local index.
        % Set during predictor() call when free_dofs is available.
        ControlDOF_local (1,1) double = 0
    end

    methods
        function obj = DispControlStrategy(controlDOF, varargin)
            obj.ControlDOF = controlDOF;
            for k = 1:2:length(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, ~, ds, free_dofs, nDofs)
        % PREDICTOR  Displacement-control predictor.
        %
        % BUG-P4 FIX: Map global ControlDOF to free-DOF local index here,
        % where free_dofs is available, and cache it for constraint() calls.
            idx = find(free_dofs == obj.ControlDOF, 1);
            if isempty(idx)
                error('DispControlStrategy:controlDOFNotFree', ...
                    'ControlDOF %d is not a free DOF.', obj.ControlDOF);
            end
            obj.ControlDOF_local = idx;

            dlp = 0;  % displacement control: lambda is solved for
            dup_f = ds * (KT_ff \ F_ext_f);
            dup = zeros(nDofs, 1);
            dup(free_dofs) = dup_f;
            u1 = u0 + dup;
            l1 = l0;
        end

        function [g, h, s] = constraint(obj, u_f, ~, u0_f, ~, ~, ~, ds)
        % CONSTRAINT  Fixed displacement increment at ControlDOF.
        %
        % Uses the local index cached during predictor() to correctly
        % index into the free-DOF displacement vector.
            dof_local = obj.ControlDOF_local;
            if dof_local < 1 || dof_local > length(u_f)
                error('DispControlStrategy:badLocalDOF', ...
                    'ControlDOF_local=%d out of range for u_f(length=%d).', ...
                    dof_local, length(u_f));
            end
            g = u_f(dof_local) - (u0_f(dof_local) + ds);
            nFree = length(u_f);
            h = zeros(nFree, 1);
            h(dof_local) = 1;
            s = 0;
        end
    end
end
