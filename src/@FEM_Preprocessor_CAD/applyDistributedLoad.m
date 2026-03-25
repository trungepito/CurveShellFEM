function applyDistributedLoad(obj, lineID, totalForceMag, directionVec)
% Applies a distributed load along a line
% Strategy: Distribute TotalForce based on segment lengths (Lumped)

% 1. Find nodes
nIDs = obj.findNodesOnLine(lineID);
coords = obj.Mesh.Nodes(nIDs, :);

% 2. Sort nodes by distance to ensure they are sequential
% (Simple sort along X or Y, or by distance from P1)
lineDef = obj.GeoLines{lineID};
P1 = obj.GeoPoints(lineDef.p1, :);
dist = vecnorm(coords - P1, 2, 2);
[~, sortIdx] = sort(dist);
sortedIDs = nIDs(sortIdx);
sortedCoords = coords(sortIdx, :);

% 3. Calculate tributary lengths
% For internal nodes: L_trib = 0.5*L_left + 0.5*L_right
% For end nodes: L_trib = 0.5*L_neighbor

numN = length(sortedIDs);
segLens = vecnorm(sortedCoords(2:end,:) - sortedCoords(1:end-1,:), 2, 2);
totalLen = sum(segLens);

% Normalize Direction
dir = directionVec / norm(directionVec);
loadPerUnitLen = totalForceMag / totalLen;

for i = 1:numN
    L_trib = 0;
    if i > 1, L_trib = L_trib + 0.5 * segLens(i-1); end
    if i < numN, L_trib = L_trib + 0.5 * segLens(i); end

    F_node = loadPerUnitLen * L_trib * dir;

    % Add to Loads
    for d = 1:3
        if F_node(d) ~= 0
            obj.Loads = [obj.Loads; sortedIDs(i), d, F_node(d)];
        end
    end
end
end