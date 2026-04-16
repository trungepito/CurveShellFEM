classdef (Abstract) IncrementalStrategy < handle
% INCREMENTALSTRATEGY  Interface for predictor-corrector increment strategies.
%
% Implementations: RiksStrategy, LoadControlStrategy, DispControlStrategy
%
% The arc-length solver calls:
%   1. predictor() once at the start of each increment
%   2. constraint() once per corrector iteration

    properties (Abstract)
        ArcLengthRadius  (1,1) double   % current ds
        ArcLengthMin     (1,1) double
        ArcLengthMax     (1,1) double
    end

    methods (Abstract)
        % PREDICTOR  Compute predicted (u1, lambda1) and store predictor direction.
        % KT_ff:     [nFree×nFree] tangent stiffness on free DOFs
        % F_ext_f:   [nFree×1] external force on free DOFs
        % u0, l0:    current converged state
        % dup_prev:  [nDofs×1] predictor from previous step (for CSP sign)
        % ds:        current arc-length radius
        % free_dofs: indices of free DOFs
        [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs)

        % CONSTRAINT  Evaluate arc-length constraint at current trial state.
        % Returns scalar g, gradient h [nFree×1], load derivative s (scalar)
        [g, h, s] = constraint(obj, u_f, lambda, u0_f, l0, dup_f, dlp, ds)
    end

    methods
        function adaptRadius(obj, iters, maxIter)
        % ADAPTRADIUS  Adjust arc-length radius based on iteration count.
            if iters <= 4
                obj.ArcLengthRadius = min(obj.ArcLengthRadius * 1.5, obj.ArcLengthMax);
            elseif iters > round(maxIter * 0.75)
                obj.ArcLengthRadius = max(obj.ArcLengthRadius * 0.7, obj.ArcLengthMin);
            end
        end
        function halveRadius(obj)
        % HALVERADIUS  Called on trial failure.
            obj.ArcLengthRadius = max(obj.ArcLengthRadius * 0.5, obj.ArcLengthMin);
        end
    end
end
