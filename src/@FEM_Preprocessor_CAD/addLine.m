function id = addLine(obj, p1_id, p2_id, type, varargin)
% type: 'straight' or 'arc'
% For arc, varargin{1} is the center point or intermediate point
L.p1 = p1_id;
L.p2 = p2_id;
L.type = type;
if strcmp(type, 'arc')
    L.center = varargin{1}; % Center point ID
end
obj.GeoLines{end+1} = L;
id = length(obj.GeoLines);
end