function mergeDuplicateNodes(obj, tol)
if nargin < 2, tol = 1e-6; end
fprintf('Merging duplicate nodes (Tolerance: %g)...\n', tol);

old_nodes = obj.Mesh.Nodes;
[unique_nodes, ~, idx_map] = uniquetol(old_nodes, tol, 'ByRows', true);

obj.Mesh.Nodes = unique_nodes;
% Remap elements
obj.Mesh.Elements = idx_map(obj.Mesh.Elements);

fprintf('  Reduced nodes from %d to %d.\n', size(old_nodes,1), size(unique_nodes,1));

% Recompute normals after merge
obj.computeNormals();
end