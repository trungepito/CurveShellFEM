function applyBC_OnLine(obj, lineID, dofs)
% Selects nodes on the geometric line and fixes DOFs
nodesOnLine = obj.findNodesOnLine(lineID);
for i = 1:length(nodesOnLine)
    for d = dofs
        obj.BCs = [obj.BCs; nodesOnLine(i), d];
    end
end
end