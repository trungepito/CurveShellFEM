function id = addLine(obj, p1, p2, type, varargin)
% type: 'straight' or 'arc'
L.p1 = p1; L.p2 = p2; L.type = type;
if strcmp(type, 'arc'), L.center = varargin{1}; end
obj.GeoLines{end+1} = L;
id = length(obj.GeoLines);
end