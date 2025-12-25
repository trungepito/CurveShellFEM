function applyLoads(obj)
nNodes = size(obj.Model.Mesh.Nodes,1);
obj.GlobalF = zeros(nNodes*6, 1);
% utilizing the table form of the Model.Loads
idx=(obj.Model.Loads.Node-1)*6+obj.Model.Loads.DOF;
obj.GlobalF(idx)=obj.GlobalF(idx)+obj.Model.Loads.Value;
end