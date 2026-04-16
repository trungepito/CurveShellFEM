function solve(obj, StageList)
% SOLVE  Unified multi-stage incremental analysis — NR and arc-length.
%
% For each stage, the active strategy (from Stage.getStrategy()) drives
% the increment type. If strategy is an IncrementalStrategy subclass,
% arc-length corrector logic runs. Otherwise, adaptive NR logic runs.
%
% This unified entry point replaces both FEM_Solver_Adaptive.solve() and
% FEM_Solver_ArcLength.solve().
%
% Syntax:
%   Sol.solve({Stage1, Stage2, ...})

fprintf('=== Nonlinear Analysis: %d stage(s) ===\n', length(StageList));
nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;

if isempty(obj.state)
    obj.state = SolutionState(nDofs, obj.Options);
end

% Initialise tracking arrays for backward compatibility
obj.History_Load = zeros(length(StageList), 1);

    for s = 1:length(StageList)
        Stage = StageList{s};
        fprintf('\n>>> Stage %d / %d\n', s, length(StageList));
        obj.state.beginStage();

        % Determine which driver to use based on strategy (A5 Unified Architecture)
        strategy = [];
        if isprop(Stage, 'strategy') || isprop(Stage, 'ConstraintType')
            strategy = Stage.getStrategy();
        end

        % Default to Standard adaptive Newton if no special strategy is provided
        if isempty(strategy) || ~isa(strategy, 'IncrementalStrategy')
            % Default radius is 1/10th of duration or from options
            ds_init = obj.Options.InitialDt; 
            if ds_init == 0, ds_init = Stage.Duration / 10; end
            strategy = StandardNewtonStrategy(ds_init);
            
            % Sync settings from Options
            strategy.ArcLengthMin = obj.Options.MinDt;
            strategy.ArcLengthMax = obj.Options.MaxDt;
        end

        % All stages now run through the unified strategy-driven driver
        success = obj.solveIncrementalStage(Stage, strategy, s);

        if ~success
            fprintf('!!! Analysis aborted at stage %d.\n', s);
            return;
        end
    end
    fprintf('\n=== Analysis complete: %d converged steps ===\n', obj.state.StepCount);
end
