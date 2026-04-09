function saveToCSV(obj, Pre, Sol, opt)
if opt.saveMesh
    f_node = fullfile(obj.OutputFolder,[obj.ProjectName '_Nodes.csv']);
    nodeData = [(1:size(Pre.Mesh.Nodes,1))', Pre.Mesh.Nodes];
    writematrix(nodeData, f_node);
    f_elem = fullfile(obj.OutputFolder,[obj.ProjectName '_Elements.csv']);
    elemData = [(1:size(Pre.Mesh.Elements,1))', Pre.Mesh.Elements];
    writematrix(elemData, f_elem);
end
if opt.saveResults
    f_res = fullfile(obj.OutputFolder,[obj.ProjectName '_Displacements.csv']);
    writematrix(Sol.U, f_res);
    if isprop(Sol,'LambdaHist') && ~isempty(Sol.LambdaHist)
        f_hist = fullfile(obj.OutputFolder,[obj.ProjectName '_LoadPath.csv']);
        writematrix([Sol.LambdaHist', Sol.U_Hist'], f_hist);
    end
end
if opt.saveHistory
    warning('[DataMgr] Plastic history cannot be exported to CSV. Use MAT.');
end
end