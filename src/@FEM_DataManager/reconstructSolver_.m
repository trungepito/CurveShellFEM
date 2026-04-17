function Sol = reconstructSolver_(~, Pre, chk)
% Build a solver from Pre, applying checkpoint displacement state.
matData = Pre.Material;
    Sol = FEM_Solver_Nonlinear(Pre, SolverOptions());
Sol.U = chk.U;
if isprop(Sol,'LambdaHist') && isfield(chk,'lambda')
    Sol.LambdaHist = chk.lambda;
end
% Restore plastic element history if available
if isfield(chk,'GPHistory') && ~isempty(chk.GPHistory) ...
   && ~isempty(Sol.Elements)
    nElems = min(length(chk.GPHistory), length(Sol.Elements));
    for e = 1:nElems
        if ~isempty(chk.GPHistory{e}) && ...
           isprop(Sol.Elements{e},'HistoryData')
            Sol.Elements{e}.HistoryData = chk.GPHistory{e};
        end
    end
end
end
