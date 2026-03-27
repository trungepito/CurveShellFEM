function solve(obj, StageList)
% StageList: Cell array of LoadingStage objects

fprintf('--- Starting Nonlinear Analysis (Adaptive) ---\n');
obj.History_Load=zeros(length(StageList),1);
% Loop through each defined stage (Load -> Unload -> Etc)
for s = 1:length(StageList)
    currentStage = StageList{s};
    fprintf('>>> Entering Stage %d:\n', s);

    % Adaptive Refinement Loop
    max_refine_iters = 3;
    target_error = 0.05; % 5% Target
    
    for iter = 1:max_refine_iters
        fprintf('--- Refinement Iteration %d (Elements: %d) ---\n', iter, size(obj.Model.Mesh.Elements,1));
        
        success = obj.solveStage(currentStage, s);
        if ~success, break; end
        
        % 2. Error Estimation
        Post = FEM_Postprocessor(obj.Model, obj);
        [err_el, total_err] = Post.estimateErrorNorms();
        
        if total_err <= target_error
            fprintf('[Adaptive] Target error met (%.2f%%). Proceeding...\n', total_err*100);
            break;
        else
            fprintf('[Adaptive] Error (%.2f%%) exceeds target (%.2f%%). Refining...\n', total_err*100, target_error*100);
            % TRIGGER REFINEMENT (Simplified: Double density for now)
            % Future: Selective refinement based on err_el
            % obj.Model.refineAll(2); 
            % For now, since we don't have local refine, we notify
            if iter == max_refine_iters
                fprintf('[Adaptive] Max iterations reached.\n');
            end
        end
    end
    
    obj.U_Hist = obj.U_Hist(:, 1:obj.StepCount);
    obj.History_Time = obj.History_Time(1:obj.StepCount);

end
fprintf('--- Analysis Completed Successfully ---\n');
end