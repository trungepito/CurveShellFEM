function meshAllPatches(obj, Nu, Nv)
% Meshes all defined patches
fprintf('[Mesher] Meshing %d patches...\n', length(obj.GeoPatches));
for i = 1:length(obj.GeoPatches)
    obj.meshQuadPatch(i, Nu, Nv);
end
% Auto-fuse after meshing to connect sections
obj.fuseNodes(1e-5);
obj.computeNormals();
end