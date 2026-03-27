function applyLoads(obj)
nNodes = size(obj.Model.Mesh.Nodes,1);
obj.GlobalF = zeros(nNodes*6, 1);
if isempty(obj.Model.Loads), return; end

if istable(obj.Model.Loads)
    % Modern table-based load interface (handles nodal and integrated surface loads)
    for i = 1:size(obj.Model.Loads, 1)
        node = obj.Model.Loads.Node{i};
        dof  = obj.Model.Loads.DOF{i};
        val  = obj.Model.Loads.Value{i};
        idx  = (node-1)*6 + dof;
        obj.GlobalF(idx) = obj.GlobalF(idx) + val;
    end
else
    % Legacy matrix form: [NodeID, DOF_Index, Value]
    idx = (obj.Model.Loads(:,1)-1)*6 + obj.Model.Loads(:,2);
    obj.GlobalF(idx) = obj.GlobalF(idx) + obj.Model.Loads(:,3);
end
end