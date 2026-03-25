function meshAllPatches(obj, Nu, Nv)
% MESHALLPATCHES - Generates an 8-node serendipity mesh for all patches.
%
% Iterates through the GeoPatches collection and generates element 
% connectivity and nodal coordinates for each quad surface.
%
% Syntax:
%   meshAllPatches(obj, Nu, Nv)
%
% Inputs:
%   Nu - Number of elements along the U-parameter [Integer]
%   Nv - Number of elements along the V-parameter [Integer]
% Meshes all defined patches
fprintf('[Mesher] Meshing %d patches...\n', length(obj.GeoPatches));
for i = 1:length(obj.GeoPatches)
    obj.meshQuadPatch(i, Nu, Nv);
end
% Auto-fuse after meshing to connect sections
obj.fuseNodes(1e-5);
obj.computeNormals();
end