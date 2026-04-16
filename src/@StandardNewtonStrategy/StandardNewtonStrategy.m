classdef StandardNewtonStrategy < IncrementalStrategy
% STANDARDNEWTONSTRATEGY  Pure load-control strategy with fixed increments.
%
% This strategy implements the standard Newton-Raphson behavior where the
% load factor is incremented via a predictor and then held constant
% during corrector iterations.
%
% v3.1: Unified architecture compatibility.

    properties
        ArcLengthRadius = 0.1   % Used as DeltaLambda in this context
        ArcLengthMin    = 1e-6
        ArcLengthMax    = 1.0
    end

    methods
        function obj = StandardNewtonStrategy(radius)
            if nargin >= 1
                obj.ArcLengthRadius = radius;
                obj.ArcLengthMax = max(radius * 10, 1.0);
            end
        end

        function [u1, l1, dup, dlp] = predictor(~, KT_ff, F_ext_f, u0, l0, ~, ds, free_dofs, nDofs)
        % PREDICTOR  Prescribes a fixed load increment dlp = ds.
            dlp = ds;
            
            % Initial tangent solve: dup_f = KT^-1 * F_ext
            dup_f = KT_ff \ F_ext_f;
            
            dup = zeros(nDofs, 1);
            dup(free_dofs) = dup_f;
            
            u1 = u0 + dlp * dup;
            l1 = l0 + dlp;
        end

        function [g, h, s] = constraint(~, ~, lambda, ~, l0, ~, ~, ds)
        % CONSTRAINT  Enforces lambda = lambda_target = l0 + ds.
        % This identifies dl = 0 during NR iterations if lambda is already 
        % at the target.
            g = lambda - (l0 + ds);
            h = []; % Grad g w.r.t u is zero for load control
            s = 1;  % Grad g w.r.t lambda is 1
        end
    end
end
