function id = addPoint(obj, x, y, z)
obj.GeoPoints(end+1, :) = [x, y, z];
id = size(obj.GeoPoints, 1);
end