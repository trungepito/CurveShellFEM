classdef LoadControlStrategy < IncrementalStrategy
% LOADCONTROLSTRATEGY  Fixed load-factor increment per step.
%
% The constraint is simply: lambda = lambda0 + ds
% This is equivalent to standard Newton-Raphson with prescribed load increments.
%
% Usage:
%   strat = LoadControlStrategy('ArcLengthRadius', 0.1);

    properties
        ArcLengthRadius = 0.1
        ArcLengthMin    = 1e-6
        ArcLengthMax    = 1.0
    end

    methods
        function obj = LoadControlStrategy(varargin)
            for k = 1:2:length(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, ~, ds, free_dofs, nDofs)
        % PREDICTOR  Pure load-control predictor.
            dlp = ds;
            dup_f = KT_ff \ (dlp * F_ext_f);
            dup = zeros(nDofs, 1);
            dup(free_dofs) = dup_f;
            u1 = u0 + dup;
            l1 = l0 + dlp;
        end

        function [g, h, s] = constraint(~, ~, lambda, ~, l0, ~, ~, ds)
        % CONSTRAINT  Fixed load-factor constraint: lambda = l0 + ds.
            g = lambda - (l0 + ds);
            h = [];  % Placeholder — will be zeros(nFree,1) from caller
            s = 1;
        end
    end
end
