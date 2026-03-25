function elemIDs = selectElementsByBox(obj, boxBounds)
% boxBounds: [xmin xmax ymin ymax zmin zmax]
% Selects elements whose CENTROID is inside box
centroids = zeros(size(obj.Mesh.Elements,1), 3);
for e = 1:size(obj.Mesh.Elements,1)
    nIDs = obj.Mesh.Elements(e,:);
    centroids(e,:) = mean(obj.Mesh.Nodes(nIDs,:));
end
mask = centroids(:,1)>=boxBounds(1) & centroids(:,1)<=boxBounds(2) & ...
    centroids(:,2)>=boxBounds(3) & centroids(:,2)<=boxBounds(4) & ...
    centroids(:,3)>=boxBounds(5) & centroids(:,3)<=boxBounds(6);
elemIDs = find(mask);
end