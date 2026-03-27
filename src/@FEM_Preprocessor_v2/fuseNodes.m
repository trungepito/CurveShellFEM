function fuseNodes(obj, tol)
fprintf('[Mesher] Fusing duplicate nodes (Tol: %g)...\n', tol);
old_nodes = obj.Mesh.Nodes;
[unique_nodes, ~, idx_map] = uniquetol(old_nodes, tol, 'ByRows', true);
obj.Mesh.Nodes = unique_nodes;
% Use reshape to ensure matrix dimensions (keep as double for indexing math)
obj.Mesh.Elements = double(reshape(idx_map(obj.Mesh.Elements), size(obj.Mesh.Elements)));
fprintf(' -> Reduced from %d to %d nodes.\n', size(old_nodes,1), size(unique_nodes,1));
end