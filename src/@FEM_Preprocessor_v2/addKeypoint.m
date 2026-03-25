function id = addKeypoint(obj, x, y, z, tag)
% Flexible addKeypoint: handles obj.addKeypoint(x, y, z, tag) OR obj.addKeypoint([x, y, z], tag)

if nargin < 2
    error('addKeypoint requires at least a coordinate vector or x-coordinate.');
end

if isvector(x) && length(x) >= 3
    % Case: obj.addKeypoint([x, y, z], ...)
    if nargin >= 3
        tag = y; % Shift optional tag
    else
        tag = '';
    end
    coords = x(1:3);
else
    % Case: obj.addKeypoint(x, y, z, tag)
    if nargin < 4
        error('addKeypoint requires x, y, z or a 3-element vector.');
    end
    coords = [x, y, z];
    if nargin < 5, tag = ''; end
end

obj.GeoPoints(end+1, :) = coords;
id = size(obj.GeoPoints, 1);
end