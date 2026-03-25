function id = addPatch(obj, l1, l2, l3, l4)
% 4-Sided Topology
obj.GeoPatches{end+1} = struct('lines', [l1, l2, l3, l4]);
id = length(obj.GeoPatches);
end