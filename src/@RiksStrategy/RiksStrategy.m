classdef RiksStrategy < IncrementalStrategy
% RIKSSTRATEGY  Crisfield (1981) spherical arc-length constraint.
%
% The solution is constrained to lie on the hyperplane normal to
% the predictor direction through the predictor point (u1, l1):
%
%   g = dup'*(u - u1) + Psi^2*dlp*(lambda - l1) = 0
%
% Usage:
%   strat = RiksStrategy('ArcLengthRadius', 0.05, 'Psi', 1.0);
%   stage.strategy = strat;

    properties
        ArcLengthRadius = 0.01
        ArcLengthMin    = 1e-6
        ArcLengthMax    = 1.0
        Psi             = 1.0  % load scaling factor
    end

    methods
        function obj = RiksStrategy(varargin)
            for k = 1:2:length(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end

        function [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs)
        % PREDICTOR  Compute Riks predictor with CSP sign detection.
            dup_f = KT_ff \ F_ext_f;
            dup = zeros(nDofs, 1);
            dup(free_dofs) = dup_f;

            % CSP sign detection
            if norm(dup_prev) < 1e-14
                sgn = 1;
            else
                sgn = sign(dot(dup_prev, dup));
                if sgn == 0, sgn = 1; end
            end

            dlp = sgn * ds / (sqrt(norm(dup_f)^2 + obj.Psi^2) + eps);
            u1 = u0 + dlp * dup;
            l1 = l0 + dlp;
        end

        function [g, h, s] = constraint(obj, u_f, lambda, u0_f, l0, dup_f, dlp, ds)
        % CONSTRAINT  Crisfield hyperplane constraint.
            u1_f  = u0_f + dlp * dup_f;
            l1    = l0   + dlp;
            g     = dup_f' * (u_f - u1_f) + obj.Psi^2 * dlp * (lambda - l1);
            h     = dup_f;
            s     = obj.Psi^2 * dlp;
            % Guard: if s is numerically zero use ds magnitude so
            % the corrector denominator (s + h'*du_I) stays well-conditioned.
            if abs(s) < 1e-14
                s = ds * obj.Psi^2;
            end
        end
    end
end
