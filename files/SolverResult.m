classdef SolverResult
    % SOLVERRESULT  Immutable value-object capturing solver output at convergence.
    %
    % SolverResult is a plain struct-like class (NOT a handle subclass).
    % MATLAB copies it by value, so the postprocessor can never see a stale
    % or overwritten state even if the originating solver is re-run.
    %
    % Construction — called automatically at the end of every solve:
    %
    %   result = SolverResult(solverObj);          % from any FEM_Solver subclass
    %   result = SolverResult(solverObj, 'arc');   % arc-length extra fields
    %
    % Usage:
    %   Post = FEM_Postprocessor(result);
    %   Post.plotField('vonMises');
    %
    % Fields are read-only after construction (SetAccess = private).
    %
    % See also: FEM_Postprocessor, FEM_Solver_Nonlinear, FEM_Solver_ArcLength

    properties (SetAccess = private)

        % ── Core solution ────────────────────────────────────────────
        U           % [nDofs x 1]  final displacement vector
        U_Hist      % [nDofs x nSteps]  per-step displacement history
        Time_Hist   % [nSteps x 1]     pseudo-time at each converged step
        StepCount   % scalar            number of converged increments

        % ── Mesh snapshot (copied by value) ──────────────────────────
        Nodes       % [nNodes x 3]
        Elements    % [nElems x 8]
        Normals     % [nNodes x 3]
        Thickness   % scalar (from Material.t)
        E           % scalar
        nu          % scalar

        % ── Element state snapshot ───────────────────────────────────
        % Cell array of HistoryData structs, one per element.
        % Copied so post-processor can compute stresses without
        % triggering any further assembly.
        ElementHistory   % {nElems x 1} cell of struct arrays

        % ── Reaction history ─────────────────────────────────────────
        % Cell array, one entry per stage: [nFixedDOFs x nSteps]
        ReactionHist     % {nStages x 1}

        % ── Arc-length extras (empty for non-arc solvers) ────────────
        LambdaHist       % [1 x nSteps]  cumulative load factor
        ArcLengthHistory % [1 x nSteps]  arc-length radius per step

        % ── Analysis metadata ────────────────────────────────────────
        SolverClass  % string   e.g. 'FEM_Solver_ArcLength'
        Timestamp    % datetime at which snapshot was taken

    end

    methods

        function obj = SolverResult(solver)
            % SolverResult(solver)
            %   solver — any FEM_Solver subclass instance after solve().
            %
            % All arrays are deep-copied.  HistoryData structs inside
            % element objects are extracted element-by-element so the
            % snapshot is self-contained.

            if nargin == 0
                % Allow default construction (e.g. in pre-allocation arrays)
                return
            end

            validateattributes(solver, {'FEM_Solver'}, {'scalar'}, ...
                'SolverResult', 'solver');

            % ── Displacement solution ─────────────────────────────────
            obj.U          = solver.U;
            nSteps         = solver.StepCount;
            obj.StepCount  = nSteps;

            if ~isempty(solver.U_Hist)
                % Trim to only the written columns
                obj.U_Hist = solver.U_Hist(:, 1:nSteps);
            else
                obj.U_Hist = zeros(numel(solver.U), 0);
            end

            if isprop(solver, 'History_Time') && ~isempty(solver.History_Time)
                obj.Time_Hist = solver.History_Time(1:nSteps);
            else
                obj.Time_Hist = zeros(nSteps, 1);
            end

            % ── Mesh snapshot ─────────────────────────────────────────
            m           = solver.Model.Mesh;
            obj.Nodes   = m.Nodes;
            obj.Elements = m.Elements;
            obj.Normals  = m.Normals;
            mat          = solver.Model.Material;
            obj.Thickness = mat.t;
            obj.E         = mat.E;
            obj.nu        = mat.nu;

            % ── Element history snapshot ──────────────────────────────
            nElems = numel(solver.Elements);
            hist   = cell(nElems, 1);
            for e = 1:nElems
                el = solver.Elements{e};
                if isprop(el, 'HistoryData') && ~isempty(el.HistoryData)
                    hist{e} = el.HistoryData;   % struct array copy
                else
                    hist{e} = [];
                end
            end
            obj.ElementHistory = hist;

            % ── Reaction history ──────────────────────────────────────
            if isprop(solver, 'ReactionHist') && ~isempty(solver.ReactionHist)
                obj.ReactionHist = solver.ReactionHist;
            else
                obj.ReactionHist = {};
            end

            % ── Arc-length extras ─────────────────────────────────────
            if isprop(solver, 'LambdaHist')
                obj.LambdaHist = solver.LambdaHist;
            else
                obj.LambdaHist = [];
            end
            if isprop(solver, 'ArcLengthHistory')
                obj.ArcLengthHistory = solver.ArcLengthHistory;
            else
                obj.ArcLengthHistory = [];
            end

            % ── Metadata ──────────────────────────────────────────────
            obj.SolverClass = class(solver);
            obj.Timestamp   = datetime('now');
        end

    end

    % ── Convenience query methods ─────────────────────────────────────
    methods

        function n = numNodes(obj)
            n = size(obj.Nodes, 1);
        end

        function n = numElements(obj)
            n = size(obj.Elements, 1);
        end

        function n = numDofs(obj)
            n = numel(obj.U);
        end

        function tf = hasPlasticity(obj)
            % True if any element carried history data at snapshot time.
            tf = any(~cellfun(@isempty, obj.ElementHistory));
        end

        function tf = isArcLength(obj)
            tf = ~isempty(obj.LambdaHist);
        end

        function u = getStepDisplacement(obj, step)
            % u = result.getStepDisplacement(step)
            % Returns the full displacement vector at a given step index.
            validateattributes(step, {'numeric'}, ...
                {'scalar','integer','>=',1,'<=',obj.StepCount}, ...
                'getStepDisplacement', 'step');
            u = obj.U_Hist(:, step);
        end

        function disp(obj)
            % Compact display so the object doesn't flood the console.
            fprintf('SolverResult  [%s]\n', obj.SolverClass);
            fprintf('  Nodes: %d   Elements: %d   DOFs: %d\n', ...
                obj.numNodes, obj.numElements, obj.numDofs);
            fprintf('  Steps: %d   Plasticity: %s   ArcLength: %s\n', ...
                obj.StepCount, ...
                mat2str(obj.hasPlasticity), ...
                mat2str(obj.isArcLength));
            fprintf('  Snapshot taken: %s\n', char(obj.Timestamp));
        end

    end

end
