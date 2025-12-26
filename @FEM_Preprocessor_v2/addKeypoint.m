function id = addKeypoint(obj, coord)
obj.GeoPoints(end+1, :) = coord;
id = size(obj.GeoPoints, 1);
end