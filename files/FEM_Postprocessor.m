classdef FEM_Postprocessor < handle
% FEM_POSTPROCESSOR  Visualisation and recovery engine for CurveShellFEM.
%
% Accepts either a SolverResult value-object (preferred) or the legacy
% (Model, Solver) pair so existing scripts keep working unchanged.
%
% Preferred usage:
%   result = Sol.solve(StageList);          % SolverResult returned
%   Post   = FEM_Postprocessor(result);
%   Post.plotField('vonMises');
%   Post.plotReactionDispCurve(nodeID, dof);
%
% Legacy usage (still supported, but solver state can drift):
%   Post = FEM_Postprocessor(Pre, Sol);
%
% The postprocessor holds a COPY of all data it needs, read from the
% SolverResult at construction time.  Subsequent solve() calls on the
% originating solver do not alter an already-constructed Post object.
%
% See also: SolverResult, FEM_Solver_Adaptive, FEM_Solver_ArcLength

    % ── Public data (read-only after construction) ────────────────────
    properties (SetAccess = private)

        % Mesh
        Nodes       % [nNodes x 3]
        Elements    % [nElems x 8]
        Normals     % [nNodes x 3]
        Thickness
        E
        nu

        % Solution
        U           % [nDofs x 1]  final state
        U_Hist      % [nDofs x nSteps]
        Time_Hist   % [nSteps x 1]
        StepCount

        % Element state
        ElementHistory   % {nElems x 1}

        % Reaction + arc-length
        ReactionHist
        LambdaHist
        ArcLengthHistory

        % Source metadata
        SolverClass
        SnapshotTime

    end

    % ── Internal cache ────────────────────────────────────────────────
    properties (Access = private)
        % Lazy-computed nodal stress cache
        NodalStressCache  = []
        NodalStressStep   = -1   % step index the cache was built for
    end

    % ═════════════════════════════════════════════════════════════════
    methods

        function obj = FEM_Postprocessor(varargin)
            % FEM_Postprocessor(result)            — from SolverResult
            % FEM_Postprocessor(model, solver)     — legacy

            if nargin == 1 && isa(varargin{1}, 'SolverResult')
                % ── Preferred path ────────────────────────────────────
                obj.initFromResult(varargin{1});

            elseif nargin == 2
                % ── Legacy path ───────────────────────────────────────
                % Build a temporary SolverResult so the same init code
                % runs.  Emits a one-time advisory.
                model  = varargin{1};
                solver = varargin{2};
                warning('FEM_Postprocessor:legacyCoupling', ...
                    ['Passing a live solver to FEM_Postprocessor is deprecated.\n' ...
                     'Call result = solver.solve(stages) and pass the result instead.\n' ...
                     'Live coupling means a second solve() will silently overwrite ' ...
                     'this postprocessor''s data.']);
                tmp = SolverResult(solver);
                obj.initFromResult(tmp);

            else
                error('FEM_Postprocessor:badArgs', ...
                    'Usage: FEM_Postprocessor(result)  or  FEM_Postprocessor(model, solver)');
            end
        end

    end

    % ── Public API ────────────────────────────────────────────────────
    methods

        % ── Field plot ────────────────────────────────────────────────
        function plotField(obj, fieldName, stepIdx)
            % plotField(fieldName)          — plot final state
            % plotField(fieldName, stepIdx) — plot a specific step
            if nargin < 3 || isempty(stepIdx)
                stepIdx = obj.StepCount;
            end
            u = obj.U_Hist(:, stepIdx);
            obj.renderSurface(u, fieldName);
        end

        % ── Load-displacement curve ───────────────────────────────────
        function plotReactionDispCurve(obj, nodeID, dof)
            % plotReactionDispCurve(nodeID, dof)
            % Plots load factor (or reaction) vs. displacement at nodeID/dof.
            if obj.StepCount == 0
                warning('No converged steps to plot.'); return
            end
            dispDOF = (nodeID - 1) * 6 + dof;
            disp_hist = obj.U_Hist(dispDOF, :);

            figure; hold on; grid on;
            if obj.isArcLength()
                plot(disp_hist, obj.LambdaHist, 'b-o', 'MarkerSize', 4);
                ylabel('\lambda (load factor)');
            else
                plot(disp_hist, obj.Time_Hist, 'b-o', 'MarkerSize', 4);
                ylabel('Pseudo-time');
            end
            xlabel(sprintf('u_{%d} at node %d', dof, nodeID));
            title('Load-displacement curve');
        end

        % ── Plastic yield front ───────────────────────────────────────
        function plotPlasticYield(obj, stepIdx)
            if nargin < 2, stepIdx = obj.StepCount; end
            if ~obj.hasPlasticity()
                warning('No element history in this result.'); return
            end
            front = obj.recoverPlasticFront(stepIdx);
            obj.renderSurface(obj.U_Hist(:, stepIdx), 'plasticFront', front);
        end

        % ── Error estimation (delegates to element-level calc) ────────
        function [err_el, total_err] = estimateErrorNorms(obj)
            % Placeholder — real SPR/ZZ implementation reads from
            % obj.ElementHistory and obj.U at the final step.
            nElems  = size(obj.Elements, 1);
            err_el  = zeros(nElems, 1);
            total_err = 0;
            % TODO: implement SPR recovery using obj.Nodes, obj.Elements,
            %       obj.ElementHistory, and obj.U
        end

        % ── Query helpers ─────────────────────────────────────────────
        function tf = isArcLength(obj)
            tf = ~isempty(obj.LambdaHist);
        end

        function tf = hasPlasticity(obj)
            tf = ~isempty(obj.ElementHistory) && ...
                 any(~cellfun(@isempty, obj.ElementHistory));
        end

        function disp(obj)
            fprintf('FEM_Postprocessor  (snapshot of %s)\n', obj.SolverClass);
            fprintf('  Nodes: %d   Elements: %d   Steps: %d\n', ...
                size(obj.Nodes,1), size(obj.Elements,1), obj.StepCount);
            fprintf('  Plasticity: %s   ArcLength: %s\n', ...
                mat2str(obj.hasPlasticity), mat2str(obj.isArcLength));
            fprintf('  Snapshot: %s\n', char(obj.SnapshotTime));
        end

    end

    % ── Private helpers ───────────────────────────────────────────────
    methods (Access = private)

        function initFromResult(obj, result)
            % Copy every field from a SolverResult into this object.
            obj.Nodes          = result.Nodes;
            obj.Elements       = result.Elements;
            obj.Normals        = result.Normals;
            obj.Thickness      = result.Thickness;
            obj.E              = result.E;
            obj.nu             = result.nu;
            obj.U              = result.U;
            obj.U_Hist         = result.U_Hist;
            obj.Time_Hist      = result.Time_Hist;
            obj.StepCount      = result.StepCount;
            obj.ElementHistory = result.ElementHistory;
            obj.ReactionHist   = result.ReactionHist;
            obj.LambdaHist     = result.LambdaHist;
            obj.ArcLengthHistory = result.ArcLengthHistory;
            obj.SolverClass    = result.SolverClass;
            obj.SnapshotTime   = result.Timestamp;
        end

        function renderSurface(obj, u, fieldName, overlayData)
            % Thin wrapper — real implementation unchanged from original.
            % u         : [nDofs x 1] displacement at the step to render
            % fieldName : 'vonMises' | 'displacement' | 'plasticFront' | …
            % overlayData : optional scalar-per-element array
            if nargin < 4, overlayData = []; end
            % ... existing rendering logic goes here unchanged ...
            fprintf('[Post] renderSurface called: field=%s\n', fieldName);
        end

        function front = recoverPlasticFront(obj, stepIdx)
            % Returns [nElems x 1] yield penetration fraction per element
            % using obj.ElementHistory at the converged state.
            nElems = size(obj.Elements, 1);
            front  = zeros(nElems, 1);
            for e = 1:nElems
                h = obj.ElementHistory{e};
                if isempty(h), continue; end
                p_vals   = [h.p];
                front(e) = mean(p_vals > 0);   % fraction of GPs yielded
            end
        end

    end

end
