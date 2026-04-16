classdef ConvergenceMonitor < handle
% CONVERGENCEMONITOR  Per-step residual diagnostics for nonlinear solvers.
%
% Records the force-residual norm at each Newton iteration and detects
% three pathological convergence patterns, recommending corrective action:
%
%   'continue'   — normal convergence, no intervention needed
%   'linesearch' — residual is oscillating; activate Armijo step damping
%   'cutback'    — residual is stagnating; reduce step size at stage level
%   'abort'      — residual is diverging; abandon this trial step immediately
%
% Usage (called inside newtonLoop):
%   mon = ConvergenceMonitor(opts);
%   mon.reset();
%   for iter = 1:maxIter
%       ...assemble R...
%       mon.record(norm(R_free), energy_err);
%       action = mon.recommend();
%       if strcmp(action,'abort'), break; end
%   end
%   mon.printSummary(stepNumber);
%
% See also: SolverOptions, FEM_Solver_Nonlinear/newtonLoop

    properties
        ResidualNorms  = []    % [1 x nIter] force-residual norm per iteration
        EnergyNorms    = []    % [1 x nIter] energy criterion value
        StagnationWin  = 4     % window length for stagnation test
        DivRatio       = 1e3   % ||R_i||/||R_0|| threshold for divergence flag
        OscillDetect   = true  % enable oscillation detection
    end

    % ------------------------------------------------------------------
    methods
        function obj = ConvergenceMonitor(opts)
            % Construct from SolverOptions (optional).
            if nargin > 0 && ~isempty(opts)
                obj.StagnationWin = opts.StagnationWindow;
                obj.DivRatio      = opts.DivergenceRatio;
            end
        end

        % --------------------------------------------------------------
        function reset(obj)
            % Call at the start of each Newton loop (each arc-length trial).
            obj.ResidualNorms = [];
            obj.EnergyNorms   = [];
        end

        % --------------------------------------------------------------
        function record(obj, r_norm, e_norm)
            % Append one iteration's norms.
            obj.ResidualNorms(end+1) = r_norm;
            if nargin > 2
                obj.EnergyNorms(end+1) = e_norm;
            end
        end

        % --------------------------------------------------------------
        function flag = isDiverging(obj)
            % True when the current residual exceeds DivRatio times the
            % first-iteration residual.  Requires at least 2 data points.
            n = numel(obj.ResidualNorms);
            if n < 2
                flag = false;
                return;
            end
            flag = obj.ResidualNorms(end) > obj.DivRatio * obj.ResidualNorms(1);
        end

        % --------------------------------------------------------------
        function flag = isStagnating(obj)
            % True when the total residual decrease over the last
            % StagnationWin iterations is less than 5 % of the window-start
            % value.
            %
            % Requires StagnationWin+1 data points (so that the window
            % contains StagnationWin intervals).
            n = numel(obj.ResidualNorms);
            w = obj.StagnationWin;
            if n < w + 1
                flag = false;
                return;
            end
            window = obj.ResidualNorms(end - w : end);   % w+1 values
            r_drop = (window(1) - window(end)) / max(window(1), 1e-30);
            flag   = r_drop < 0.05;
        end

        % --------------------------------------------------------------
        function flag = isOscillating(obj)
            % True when the residual sequence changes direction at least
            % twice in the last four data points (three first-differences).
            %
            % Oscillation = sign changes in diff(R), not diff(diff(R)).
            % Requires exactly 4 data points to yield 3 differences.
            if ~obj.OscillDetect
                flag = false;
                return;
            end
            n = numel(obj.ResidualNorms);
            if n < 4
                flag = false;
                return;
            end
            d     = diff(obj.ResidualNorms(end-3 : end));   % 3 differences
            sg    = sign(d);
            % Count sign changes in consecutive difference signs
            nflip = sum(sg(1:end-1) ~= sg(2:end));
            flag  = nflip >= 2;
        end

        % --------------------------------------------------------------
        function action = recommend(obj)
            % Returns the recommended corrective action as a char string.
            % Priority: abort > oscillating > stagnating > continue.
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

        % --------------------------------------------------------------
        function printSummary(obj, stepNum)
            % Print a one-line convergence summary for the completed step.
            n = numel(obj.ResidualNorms);
            if n == 0, return; end
            ratio = obj.ResidualNorms(end) / max(obj.ResidualNorms(1), 1e-30);
            fprintf(['  [Monitor] Step %3d | %2d iters | ' ...
                     'R0=%.2e  Rf=%.2e  ratio=%.2e\n'], ...
                stepNum, n, obj.ResidualNorms(1), obj.ResidualNorms(end), ratio);
        end
    end
end
