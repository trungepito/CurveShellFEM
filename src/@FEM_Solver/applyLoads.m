function applyLoads(obj)
nNodes = size(obj.Model.Mesh.Nodes,1);
obj.GlobalF = zeros(nNodes*6, 1);
if isempty(obj.Model.Loads), return; end

if istable(obj.Model.Loads)
    % Utilizing the table form of the Model.Loads (Modern)
    idx=(obj.Model.Loads.Node-1)*6+obj.Model.Loads.DOF;
    obj.GlobalF(idx)=obj.GlobalF(idx)+obj.Model.Loads.Value;
else
    % Matrix form: [NodeID, DOF_Index, Value] (Legacy)
    idx = (obj.Model.Loads(:,1)-1)*6 + obj.Model.Loads(:,2);
    obj.GlobalF(idx) = obj.GlobalF(idx) + obj.Model.Loads(:,3);
end
end