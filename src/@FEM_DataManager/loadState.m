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
Pre = FEM_Preprocessor(matData.E, matData.nu, matData.t);
Pre.Mesh = data.Mesh;
Pre.BCs  = data.BCs;
Pre.Loads = data.Loads;
if isfield(data,'GlobalHistory') && ~isempty(data.GlobalHistory)
    MatObj = Material_J2Plastic(matData.E, matData.nu, ...
        matData.Yield, matData.H);
    Sol = FEM_Solver_Plastic(Pre, MatObj);
    Sol.GlobalHistory = data.GlobalHistory;
else
    Sol = FEM_Solver(Pre);
end
Sol.U = data.U;
if isfield(data,'BucklingFactors'), Sol.BucklingFactors = data.BucklingFactors; end
if isfield(data,'LambdaHist'),      Sol.LambdaHist      = data.LambdaHist;      end
if isfield(data,'U_Hist'),          Sol.U_Hist          = data.U_Hist;          end
fprintf('[DataMgr] Load complete.\n');
end