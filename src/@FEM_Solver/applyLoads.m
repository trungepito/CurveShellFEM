function applyLoads(obj)
nNodes = size(obj.Model.Mesh.Nodes,1);
obj.GlobalF = zeros(nNodes*6, 1);
if isempty(obj.Model.Loads), return; end

if istable(obj.Model.Loads)
    % Modern table-based load interface (handles nodal and integrated surface loads)
    % Modern table-based load interface
    Loads = obj.Model.Loads;
    if iscell(Loads.Node), Nodes = cell2mat(Loads.Node); else, Nodes = double(Loads.Node); end
    if iscell(Loads.DOF), DOFs = cell2mat(Loads.DOF); else, DOFs = double(Loads.DOF); end
    if iscell(Loads.Value), Values = cell2mat(Loads.Value); else, Values = double(Loads.Value); end
    
    for i = 1:size(Loads, 1)
        node = Nodes(i);
        dof  = DOFs(i);
        val  = Values(i);
        idx  = (node-1)*6 + dof;
        obj.GlobalF(idx) = obj.GlobalF(idx) + val;
    end
else
    % Legacy matrix form: [NodeID, DOF_Index, Value]
    idx = (obj.Model.Loads(:,1)-1)*6 + obj.Model.Loads(:,2);
    obj.GlobalF(idx) = obj.GlobalF(idx) + obj.Model.Loads(:,3);
end
end