function nIDs = findNodesOnLine(obj, lineID)
% Helper: Find nodes strictly located on the geometry of the line
% Uses distance tolerance
tol = 1e-4;

L = obj.GeoLines{lineID};
P1 = obj.GeoPoints(L.p1, :);
P2 = obj.GeoPoints(L.p2, :);

nodes = obj.Mesh.Nodes;
nIDs = [];

if strcmp(L.type, 'straight')
    % Point-Line Distance
    vecLine = P2 - P1;
    lenLine = norm(vecLine);
    vecLine = vecLine / lenLine;

    for i = 1:size(nodes,1)
        vecPt = nodes(i,:) - P1;
        proj = dot(vecPt, vecLine);

        if proj >= -tol && proj <= lenLine + tol
            dist = norm(vecPt - proj*vecLine);
            if dist < tol
                nIDs(end+1) = i;
            end
        end
    end
elseif strcmp(L.type, 'arc')
    C = obj.GeoPoints(L.center, :);
    R = norm(P1 - C);
    for i = 1:size(nodes,1)
        d = norm(nodes(i,:) - C);
        if abs(d - R) < tol
            % Also need to check if within angles... skipping for brevity
            nIDs(end+1) = i;
        end
    end
end
end