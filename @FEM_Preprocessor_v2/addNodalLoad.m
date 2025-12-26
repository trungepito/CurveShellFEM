function addNodalLoad(obj, nodes, dofs, value,tag)
% Direct Nodal Load, the fundamental load adding method!!
for i = 1:length(nodes)
    for j = 1:length(dofs)
        newRow = {nodes(i), dofs(j), value, tag};
        obj.Loads = [obj.Loads; newRow];
    end
end
end