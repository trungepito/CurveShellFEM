function saveToMAT(obj, Pre, Sol, opt)
% Prepares a structured struct to save as a single binary file
Data = struct();

% 1. Save Mesh & Material
if opt.saveMesh
    Data.Mesh = Pre.Mesh;
    Data.MaterialData = struct('E', Pre.Material.E, ...
        'nu', Pre.Material.nu, ...
        't', Pre.Material.t);
    % Save Plastic props if they exist
    if isa(Pre.Material, 'Material_J2Plastic') || (isprop(Sol, 'Material') && isa(Sol.Material, 'Material_J2Plastic'))
        % Handle finding the properties depending on where they are stored
        if isprop(Sol, 'Material')
            Data.MaterialData.Yield = Sol.Material.YieldStress;
            Data.MaterialData.H = Sol.Material.H;
        end
    end
end

% 2. Save Boundary Conditions
if opt.saveBCs
    Data.BCs = Pre.BCs;
    Data.Loads = Pre.Loads;
end

% 3. Save Results
if opt.saveResults
    Data.U = Sol.U;
    if ~isempty(Sol.BucklingFactors), Data.BucklingFactors = Sol.BucklingFactors; end
    if isprop(Sol, 'LambdaHist'), Data.LambdaHist = Sol.LambdaHist; end
    if isprop(Sol, 'U_Hist'), Data.U_Hist = Sol.U_Hist; end
end

% 4. Save History (Plasticity)
if opt.saveHistory && isprop(Sol, 'GlobalHistory')
    Data.GlobalHistory = Sol.GlobalHistory;
end

% Write to disk
fname = fullfile(obj.OutputFolder, [obj.ProjectName '_FullState.mat']);
save(fname, '-struct', 'Data');
end