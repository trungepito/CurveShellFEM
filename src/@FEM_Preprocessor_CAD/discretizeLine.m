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

    % Angles (assuming 2D XY plane for simplicity, or localized plane)
    ang1 = atan2(R_vec1(2), R_vec1(1));
    ang2 = atan2(R_vec2(2), R_vec2(1));

    % Handle wrapping
    if ang2 < ang1, ang2 = ang2 + 2*pi; end

    theta = linspace(ang1, ang2, nPts)';
    pts = zeros(nPts, 3);
    pts(:,1) = C(1) + Radius*cos(theta);
    pts(:,2) = C(2) + Radius*sin(theta);
    pts(:,3) = C(3); % Flat arc in Z
end
end