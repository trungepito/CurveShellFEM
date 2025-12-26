function pts = discretizeLine(obj, lineID, nPts)
% Helper to generate points along a GeoLine
L = obj.GeoLines{lineID};
P1 = obj.GeoPoints(L.p1, :);
P2 = obj.GeoPoints(L.p2, :);

if strcmp(L.type, 'straight')
    vec = P2 - P1;
    s = linspace(0, 1, nPts)';
    pts = P1 + s * vec;
elseif strcmp(L.type, 'arc')
    % Circular Arc Logic
    C = obj.GeoPoints(L.center, :);
    R_vec1 = P1 - C;
    R_vec2 = P2 - C;
    Radius = norm(R_vec1);
    % let assume the angle is always smaller than 90, this is not true but
    % let use it for now, in the upgrade version this one should be changed
    angle=acos(R_vec1*R_vec2'/(norm(R_vec1)*norm(R_vec2)));
    v3=cross(R_vec1,R_vec2);v3=v3/norm(v3);
    v1=R_vec1/Radius;
    v2=cross(v3,v1);v2=v2/norm(v2);
    % map_matrix=[v1;v2;v3];
    % Handle wrapping
    theta = linspace(0, angle, nPts)';
    % pts=map_matrix*[Radius*cos(theta);Radius*sin(theta);zeros(1,nPts)];
    % pts=pts'+C;
    pts = C + Radius * [cos(theta), sin(theta)] * [v1; v2];   
    % This line of code is tricky line, i still dont understand why the
    % previous one is not correct+))
end
end