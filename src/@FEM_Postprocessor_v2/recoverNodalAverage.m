function nodalVals = recoverNodalAverage(obj, gpCell, fieldName)
% RECOVERNODALAVERGE  Fallback: distance-weighted nodal average of GP values.
%
% Used when SPR is unavailable (degenerate patch, boundary nodes, or when
% the caller explicitly requests a quick non-superconvergent projection).
%
% For each node, all Gauss points from all patch elements are collected.
% The nodal value is the inverse-distance weighted average using the
% physical distance between each GP and the node.
%
% Input / Output: identical to recoverNodalSPR.

Nodes    = obj.Model.Mesh.Nodes;
Elements = double(obj.Model.Mesh.Elements);
nNodes   = size(Nodes, 1);
nElems   = size(Elements, 1);

gpScalars = obj.extractGPScalar(gpCell, fieldName);

% Build connectivity
nodePatch = cell(nNodes, 1);
for e = 1:nElems
    for k = 1:8
        nodePatch{Elements(e,k)}(end+1) = e;
    end
end

% GP natural coords (2×2 in-plane)
sqrt3_inv = 1 / sqrt(3);
gp_xi_in  = [-sqrt3_inv, -sqrt3_inv,  sqrt3_inv,  sqrt3_inv];
gp_eta_in = [-sqrt3_inv,  sqrt3_inv, -sqrt3_inv,  sqrt3_inv];

nodalVals = zeros(nNodes, 1);

for n = 1:nNodes
    patchElems = nodePatch{n};
    if isempty(patchElems), continue; end

    xn = Nodes(n, 1);  yn = Nodes(n, 2);
    sumW = 0;  sumV = 0;

    for idx = 1:length(patchElems)
        e        = patchElems(idx);
        nIdx     = Elements(e, :);
        elCoords = Nodes(nIdx, :);
        scals    = gpScalars{e};

        for iGP = 1:4
            xi  = gp_xi_in(iGP);
            eta = gp_eta_in(iGP);
            [N, ~] = Curve8Element.fmisoq8(xi, eta);
            x_gp  = N * elCoords(:,1);
            y_gp  = N * elCoords(:,2);
            dist  = sqrt((x_gp - xn)^2 + (y_gp - yn)^2);

            if dist < 1e-12
                % Node coincides with GP → exact value
                nodalVals(n) = scals((iGP-1)*5 + 3);
                sumW = -1;
                break;
            end

            w    = 1 / dist;
            sumW = sumW + w;
            sumV = sumV + w * scals((iGP-1)*5 + 3);
        end
        if sumW < 0, break; end
    end

    if sumW > 0
        nodalVals(n) = sumV / sumW;
    end
end
end
