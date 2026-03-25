function saveToCSV(obj, Pre, Sol, opt)
% Writes separate CSV files for each data type

% 1. Nodes
if opt.saveMesh
    f_node = fullfile(obj.OutputFolder, [obj.ProjectName '_Nodes.csv']);
    % Add Node ID column
    nodeData = [(1:size(Pre.Mesh.Nodes,1))', Pre.Mesh.Nodes];
    writematrix(nodeData, f_node);

    f_elem = fullfile(obj.OutputFolder, [obj.ProjectName '_Elements.csv']);
    % Add Elem ID column
    elemData = [(1:size(Pre.Mesh.Elements,1))', Pre.Mesh.Elements];
    writematrix(elemData, f_elem);
end

% 2. Displacements (Vector)
if opt.saveResults
    f_res = fullfile(obj.OutputFolder, [obj.ProjectName '_Displacements.csv']);
    writematrix(Sol.U, f_res);

    % Save Load History if Arc Length
    if isprop(Sol, 'LambdaHist') && ~isempty(Sol.LambdaHist)
        f_hist = fullfile(obj.OutputFolder, [obj.ProjectName '_LoadPath.csv']);
        pathData = [Sol.LambdaHist', Sol.U_Hist']; % Transpose to columns
        writematrix(pathData, f_hist);
    end
end

% Note: Complex Struct History (Plasticity) is very hard to map to CSV
% generically without flattening. We skip it for CSV export or save simplified metrics.
if opt.saveHistory
    warning('Detailed Plastic History struct cannot be exported to CSV. Use MAT format.');
end
end