function ids = selectNodesByBox(obj, xmin, xmax, ymin, ymax, zmin, zmax)
nodes = obj.Mesh.Nodes;
mask = nodes(:,1)>=xmin & nodes(:,1)<=xmax & ...
    nodes(:,2)>=ymin & nodes(:,2)<=ymax & ...
    nodes(:,3)>=zmin & nodes(:,3)<=zmax;
ids = find(mask);
end