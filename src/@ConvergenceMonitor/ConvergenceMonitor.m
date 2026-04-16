classdef ConvergenceMonitor < handle
% CONVERGENCEMONITOR  Pluggable convergence checking for iterative solvers.
%
% NormType options:
%   'force'        ||R(free)|| / max(||F_ext(free)||, 1)   [default]
%   'energy'       |dU · R| / max(|dU_0 · R_0|, 1)
%   'displacement' ||dU(free)|| / max(||U(free)||, 1)

    properties
        Tolerance     (1,1) double  = 1e-6
        MaxIterations (1,1) double  = 25
        NormType      char          = 'force'
        
        % History vectors (growing dynamically)
        ResidualHistory             double   % [nIter x 1] error used for convergence check
        RawNormHistory              double   % [nIter x 1] raw ||R|| or Energy
        IterationsUsed (1,1) double = 0
        
        % Advanced Diagnostics Settings
        StagnationWin  (1,1) double = 4
        DivRatio       (1,1) double = 1e3
        OscillDetect   (1,1) logical = true
    end

    properties (Access = private)
        Ref0  (1,1) double = 1.0   % reference norm (first iteration)
        dU0_R0 (1,1) double = 1.0  % energy reference
    end

    methods

        function reset(obj, F_ext_free, opts)
        % RESET  Call at the start of each Newton step.
            obj.Ref0 = max(norm(F_ext_free), 1.0);
            obj.dU0_R0 = 1.0;
            obj.ResidualHistory = [];
            obj.RawNormHistory  = [];
            obj.IterationsUsed = 0;
            
            % Update settings from options if provided
            if nargin > 2 && ~isempty(opts)
                if isprop(opts, 'StagnationWindow'), obj.StagnationWin = opts.StagnationWindow; end
                if isprop(opts, 'DivergenceRatio'),  obj.DivRatio      = opts.DivergenceRatio;  end
            end
        end

        function ok = check(obj, R_free, dU_free, U_total_free, F_ext_free, iter)
        % CHECK  Evaluate convergence at current iteration.
        % Returns true if converged.
            
            raw_r = norm(R_free);
            
            switch obj.NormType
                case 'force'
                    err = raw_r / obj.Ref0;
                case 'energy'
                    e_curr = abs(dU_free' * R_free);
                    if iter == 1
                        obj.dU0_R0 = max(e_curr, 1e-30);
                    end
                    err = e_curr / obj.dU0_R0;
                    raw_r = e_curr; % store energy as raw norm for diagnostics
                case 'displacement'
                    U_total_norm = max(norm(U_total_free), 1e-30);
                    err = norm(dU_free) / U_total_norm;
                    raw_r = norm(dU_free);
                otherwise
                    err = raw_r / obj.Ref0;
            end
            
            obj.ResidualHistory(end+1, 1) = err;
            obj.RawNormHistory(end+1, 1)  = raw_r;
            obj.IterationsUsed = iter;
            ok = (err <= obj.Tolerance);
        end

        % --- Advanced Recommendation Logic (E6) ---
        
        function action = recommend(obj)
        % RECOMMEND  Returns corrective action string based on history.
            if obj.isDiverging()
                action = 'abort';
            elseif obj.isOscillating()
                action = 'linesearch';
            elseif obj.isStagnating()
                action = 'cutback';
            else
                action = 'continue';
            end
        end

        function flag = isDiverging(obj)
            n = obj.IterationsUsed;
            if n < 2, flag = false; return; end
            flag = obj.RawNormHistory(end) > obj.DivRatio * obj.RawNormHistory(1);
        end

        function flag = isStagnating(obj)
            n = obj.IterationsUsed;
            w = obj.StagnationWin;
            if n < w + 1, flag = false; return; end
            window = obj.RawNormHistory(end-w : end);
            r_drop = (window(1) - window(end)) / max(window(1), 1e-30);
            flag = r_drop < 0.05; % less than 5% progress over window
        end

        function flag = isOscillating(obj)
            if ~obj.OscillDetect, flag = false; return; end
            n = obj.IterationsUsed;
            if n < 4, flag = false; return; end
            d = diff(obj.RawNormHistory(end-3 : end));
            sg = sign(d);
            nflip = sum(sg(1:end-1) ~= sg(2:end));
            flag = nflip >= 2;
        end

        function report(obj)
        % REPORT  Print convergence history for this step.
            fprintf('  Convergence history (%s norm):\n', obj.NormType);
            for k = 1:obj.IterationsUsed
                marker = '';
                if k == obj.IterationsUsed && obj.ResidualHistory(k) <= obj.Tolerance
                    marker = ' [CONVERGED]';
                end
                fprintf('    iter %2d: %.4e%s\n', k, obj.ResidualHistory(k), marker);
            end
        end
    end
end
