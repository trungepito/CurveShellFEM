function applyLoads(obj)
nNodes = size(obj.Model.Mesh.Nodes,1);
obj.GlobalF = zeros(nNodes*5, 1);
loads = obj.Model.Loads;
for i = 1:size(loads, 1)
    idx = (loads(i,1)-1)*5 + loads(i,2);
    obj.GlobalF(idx) = obj.GlobalF(idx) + loads(i,3);
end
end