function id = addPatch(obj, l1, l2, l3, l4)
% Defines a 4-sided surface bounded by 4 Line IDs
% Order must be counter-clockwise loop
P.lines = [l1, l2, l3, l4];
obj.GeoPatches{end+1} = P;
id = length(obj.GeoPatches);
end