function saveToMAT(obj, Pre, Sol, opt)
Data = struct();
if opt.saveMesh
    Data.Mesh         = Pre.Mesh;
    Data.MaterialData = struct('E',Pre.Material.E,'nu',Pre.Material.nu,...
        't',Pre.Material.t);
    if isprop(Sol,'Material') && isa(Sol.Material,'Material_J2Plastic')
        Data.MaterialData.Yield = Sol.Material.YieldStress;
        Data.MaterialData.H     = Sol.Material.H;
    end
end
if opt.saveBCs
    Data.BCs   = Pre.BCs;
    Data.Loads = Pre.Loads;
end
if opt.saveResults
    Data.U = Sol.U;
    if ~isempty(Sol.BucklingFactors)
        Data.BucklingFactors = Sol.BucklingFactors;
    end
    if isprop(Sol,'LambdaHist') && ~isempty(Sol.LambdaHist)
        Data.LambdaHist = Sol.LambdaHist;
    end
    if isprop(Sol,'U_Hist') && ~isempty(Sol.U_Hist)
        Data.U_Hist = Sol.U_Hist;
    end
end
fname = fullfile(obj.OutputFolder, [obj.ProjectName '_FullState.mat']);
save(fname, '-struct', 'Data', '-v7.3');
fprintf('[DataMgr] Snapshot saved to %s\n', fname);
end