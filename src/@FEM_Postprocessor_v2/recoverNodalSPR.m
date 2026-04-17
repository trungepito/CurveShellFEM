function nodalVals = recoverNodalSPR(obj, gpCell, fieldName)
% RECOVERNODALSPR  Stage 2: Superconvergent Patch Recovery (Zienkiewicz-Zhu).
%
% For each node, assembles the patch of elements sharing that node.
% Within the patch a bilinear polynomial p(xi,eta) = a0 + a1*xi + a2*eta
% is fitted in the least-squares sense to the mid-layer Gauss-point values
% from all patch elements.  The polynomial is evaluated at the natural
% coordinates of the node within each patch element and the results averaged.
%
% Using natural coordinates (xi,eta) rather than physical (x,y) makes the
% fit geometrically consistent for curved shells, where a linear polynomial
% in physical coordinates would be distorted by shell curvature.
%
% Degenerate patches (< 3 GPs) fall back to distance-weighted averaging.
%
% Reference: Zienkiewicz & Zhu (1992), Int. J. Numer. Methods Eng. 33.
%
% Input / Output: see FEM_Postprocessor_v2 class header.

Nodes    = obj.Model.Mesh.Nodes;
Elements = double(obj.Model.Mesh.Elements);
nNodes   = size(Nodes, 1);
nElems   = size(Elements, 1);

% ── 1. Extract raw GP scalars ────────────────────────────────────
gpScalars = obj.extractGPScalar(gpCell, fieldName);

% ── 2. Build node → element patch map ───────────────────────────
nodePatch = cell(nNodes, 1);
for e = 1:nElems
    for k = 1:8
        n = Elements(e, k);
        if isempty(nodePatch{n})
            nodePatch{n} = e;
        else
            nodePatch{n}(end+1) = e; %#ok<AGROW> — patch size is O(8), not O(N)
        end
    end
end

% ── 3. GP natural coordinates (2×2 in-plane, mid-layer zeta=0) ──
sqrt3_inv  = 1 / sqrt(3);
gp_xi_in   = [-sqrt3_inv, -sqrt3_inv,  sqrt3_inv,  sqrt3_inv];
gp_eta_in  = [-sqrt3_inv,  sqrt3_inv, -sqrt3_inv,  sqrt3_inv];
n_inplane  = 4;  % GPs per element used in SPR fit

% Node natural coordinates within a biunit square (corner/midside positions)
% Order matches Curve8Element connectivity: corners 1-4, midsides 5-8
xi_node  = [-1,  1,  1, -1,  0,  1,  0, -1];
eta_node = [-1, -1,  1,  1, -1,  0,  1,  0];

% Pre-compute maximum patch size to pre-allocate inner arrays.
% Max patch for an interior node of an NxN mesh ≈ 4 elements × 4 GPs = 16.
% Allocate 32 to be safe; truncate before use.
max_patch_gp = 32;

nodalVals = zeros(nNodes, 1);

for n = 1:nNodes
    patchElems = nodePatch{n};
    nPatch     = length(patchElems);
    if nPatch == 0, continue; end

    % Pre-allocate (over-sized, trimmed after fill)
    X_gp = zeros(nPatch * n_inplane, 2);  % [xi, eta] of each GP
    V_gp = zeros(nPatch * n_inplane, 1);  % scalar value
    cnt  = 0;

    for idx = 1:nPatch
        e     = patchElems(idx);
        scals = gpScalars{e};          % [20×1]

        for iGP = 1:n_inplane
            cnt          = cnt + 1;
            % pt_mid       = (iGP - 1)*5 + 3;   % mid-layer (zeta=0)
            % pt_mid       = (iGP - 1)*5 + 1;   % top-layer (zeta=1)
            pt_mid       = (iGP - 1)*5 + 4;   % semi-bot-layer (zeta=1)
            X_gp(cnt, :) = [gp_xi_in(iGP), gp_eta_in(iGP)];
            V_gp(cnt)    = scals(pt_mid);
        end
    end

    X_gp = X_gp(1:cnt, :);
    V_gp = V_gp(1:cnt);

    if cnt < 3
        % Degenerate: simple average
        nodalVals(n) = mean(V_gp);
        continue;
    end

    % LS fit:  [1, xi, eta] * a = V
    A_mat  = [ones(cnt,1), X_gp];   % [cnt × 3]
    a_coef = A_mat \ V_gp;          % [3 × 1]

    % Evaluate polynomial at node n, averaged over all patch elements
    % (node n occupies a different local position in each patch element)
    nodeEst = 0;
    for idx = 1:nPatch
        e       = patchElems(idx);
        nIdx    = Elements(e, :);
        % Find which local node index this global node n corresponds to
        locIdx  = find(nIdx == n, 1);
        if isempty(locIdx), continue; end
        xi_n    = xi_node(locIdx);
        eta_n   = eta_node(locIdx);
        nodeEst = nodeEst + [1, xi_n, eta_n] * a_coef;
    end
    nodalVals(n) = nodeEst / nPatch;
end
end
