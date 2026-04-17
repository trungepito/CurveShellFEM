function [Pre, Sol] = loadState(obj)
% LOADSTATE  Legacy interface — reads monolithic _FullState.mat.
if strcmp(obj.Format, 'CSV')
    error('Full restart loading is only supported in MAT mode.');
end
filename = fullfile(obj.OutputFolder, [obj.ProjectName '_FullState.mat']);
if ~exist(filename, 'file')
    error('File not found: %s', filename);
end
fprintf('[DataMgr] Loading state from %s...\n', filename);
data = load(filename);
matData = data.MaterialData;
Pre = FEM_Preprocessor_v2(matData.E, matData.nu, matData.t);
Pre.Mesh = data.Mesh;
Pre.BCs  = data.BCs;
Pre.Loads = data.Loads;

    % Reconstruct solver — nonlinear analysis uses FEM_Solver_Nonlinear
    if isfield(matData, 'Yield') && isfield(matData, 'H')
        Pre.setMaterialPlastic(matData.Yield, matData.H);
    end
    Sol = FEM_Solver_Nonlinear(Pre, SolverOptions());
    % Restore plastic GP history to element cache
    if isprop(Sol, 'Elements') && ~isempty(Sol.Elements)
        nElems = length(Sol.Elements);
        for e = 1:nElems
            if isprop(Sol.Elements{e}, 'HistoryData') && ...
               e <= length(data.GlobalHistory)
                Sol.Elements{e}.HistoryData = data.GlobalHistory{e};
            end
        end
    end
else
    Sol = FEM_Solver(Pre);
end

Sol.U = data.U;
if isfield(data,'BucklingFactors'), Sol.BucklingFactors = data.BucklingFactors; end
if isfield(data,'LambdaHist'),      Sol.LambdaHist      = data.LambdaHist;      end
if isfield(data,'U_Hist'),          Sol.U_Hist          = data.U_Hist;          end
fprintf('[DataMgr] Load complete.\n');
end