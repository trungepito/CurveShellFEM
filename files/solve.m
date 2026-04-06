function result = solve(obj, StageList)
% SOLVE  Stage-based adaptive Newton-Raphson analysis.
%
% result = obj.solve(StageList)
%
% Returns a SolverResult value-object capturing the full solution state.
% The caller owns that snapshot; subsequent solve() calls do not alter it.

fprintf('--- Starting Nonlinear Analysis (Adaptive) ---\n');
obj.History_Load = zeros(length(StageList), 1);

for s = 1:length(StageList)
    currentStage = StageList{s};
    fprintf('>>> Entering Stage %d:\n', s);

    max_refine_iters = 3;
    target_error     = 0.05;

    for iter = 1:max_refine_iters
        fprintf('--- Refinement Iteration %d (Elements: %d) ---\n', ...
            iter, size(obj.Model.Mesh.Elements, 1));

        success = obj.solveStage(currentStage, s);
        if ~success, break; end

        Post = FEM_Postprocessor(obj.Model, obj);
        [~, total_err] = Post.estimateErrorNorms();

        if total_err <= target_error
            fprintf('[Adaptive] Target error met (%.2f%%). Proceeding...\n', ...
                total_err * 100);
            break;
        else
            fprintf('[Adaptive] Error (%.2f%%) exceeds target (%.2f%%). Refining...\n', ...
                total_err * 100, target_error * 100);
            if iter == max_refine_iters
                fprintf('[Adaptive] Max iterations reached.\n');
            end
        end
    end

    obj.U_Hist      = obj.U_Hist(:, 1:obj.StepCount);
    obj.History_Time = obj.History_Time(1:obj.StepCount);
end

fprintf('--- Analysis Completed Successfully ---\n');

% ── Snapshot ──────────────────────────────────────────────────────────
% Package all output into an immutable value-object.  The caller stores
% this; the solver object can be discarded or re-used without risk.
result = obj.snapshotResult();
end
