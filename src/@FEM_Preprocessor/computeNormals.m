function computeNormals(obj)
% Geometric calculation of normals
numNodes = size(obj.Mesh.Nodes, 1);
normals = zeros(numNodes, 3);

for e = 1:size(obj.Mesh.Elements, 1)
    idx = obj.Mesh.Elements(e, :);
    pts = obj.Mesh.Nodes(idx, :);
    % Cross product of diagonals for approximate normal
    v1 = pts(3,:) - pts(1,:);
    v2 = pts(4,:) - pts(2,:);
    n_face = cross(v1, v2);
    n_face = n_face / norm(n_face);
    for k=1:8, normals(idx(k),:) = normals(idx(k),:) + n_face; end
end

% Normalize
for i=1:numNodes
    normals(i,:) = normals(i,:) / norm(normals(i,:));
end
obj.Mesh.Normals = normals;
end