function [fixed_dofs, targets] = getDispload(obj, ActiveBCs)
    % GETDISPLOAD - Identifies constrained DOFs and prescribed values.
    fixed_dofs = [];
    targets = [];
    if isempty(ActiveBCs), return; end
    
    BCs = obj.Model.BCs;
    if iscell(BCs.Node), Nodes = cell2mat(BCs.Node); else, Nodes = double(BCs.Node); end
    if iscell(BCs.DOF), DOFs = cell2mat(BCs.DOF); else, DOFs = double(BCs.DOF); end
    if iscell(BCs.Value), Values = cell2mat(BCs.Value); else, Values = double(BCs.Value); end
    Tags = BCs.Tag;
    
    for i = 1:size(BCs,1)
        if any(strcmp(Tags{i}, ActiveBCs))
            idx = (Nodes(i)-1)*6 + DOFs(i);
            fixed_dofs = [fixed_dofs; idx];
            targets = [targets; Values(i)];
        end
    end
end
