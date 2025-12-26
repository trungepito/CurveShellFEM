function ids = selectNodesByCylinder(obj, axis, center, radius, tol)
% axis: 1=X, 2=Y, 3=Z
% center: [c1, c2] coordinates on the plane orthogonal to axis
nodes = obj.Mesh.Nodes;
if axis == 3 % Z-cylinder
    r = sqrt((nodes(:,1)-center(1)).^2 + (nodes(:,2)-center(2)).^2);
elseif axis == 2 % Y-cylinder
    r = sqrt((nodes(:,1)-center(1)).^2 + (nodes(:,3)-center(2)).^2);
else % X-cylinder
    r = sqrt((nodes(:,2)-center(1)).^2 + (nodes(:,3)-center(2)).^2);
end
ids = find(abs(r - radius) < tol);
end