function solve(obj, StageList)
% StageList: Cell array of LoadingStage objects

fprintf('--- Starting Nonlinear Analysis (Adaptive) ---\n');
obj.History_Load=zeros(length(StageList),1);
% Loop through each defined stage (Load -> Unload -> Etc)
for s = 1:length(StageList)
    currentStage = StageList{s};
    fprintf('>>> Entering Stage %d:\n', s);

    obj.ReactionHist{s}=[];
    % Solve this specific stage
    success = obj.solveStage(currentStage,s);

    if ~success
        fprintf('!!! Analysis Aborted at Stage %d !!!\n', s);
        return;
    end
    obj.U_Hist=obj.U_Hist(:,1:obj.StepCount);
    obj.History_Time=obj.History_Time(1:obj.StepCount);

end
fprintf('--- Analysis Completed Successfully ---\n');
end