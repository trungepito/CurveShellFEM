function [KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)
% ASSEMBLETANGENTSYSTEM Unified assembly of Global KT, F_int, and Trial History
% If U_curr is not provided, uses obj.U (standard for nonlinear solvers)

if nargin < 2
    U_curr = obj.U;
end

nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 6;

% Use triplet assembly for speed
nElems = size(obj.Model.Mesh.Elements, 1);
nz_per_elem = 48*48;
estnz = int32(nz_per_elem * nElems);
I = zeros(estnz, 1); J = zeros(estnz, 1); V = zeros(estnz, 1);
count = 0;

F_int = zeros(nDofs, 1);
TrialHist = cell(nElems, 1); % Store trial states

% Pre-compute scatter pattern for a single element to avoid meshgrid in loop
[ii_base, jj_base] = meshgrid(1:48, 1:48);

for e = 1:nElems
    sctr = obj.SctrMap(e, :);

    % Vectorized Extraction of Element Displacement
    u_el = U_curr(sctr);

    % Call the element method (Optimized cache)
    elObj = obj.Elements{e};
    [KT_global, fe, NewHist] = elObj.computeGlobalMatrix6DOF(u_el);
    TrialHist{e} = NewHist;

    % Assemble F_int
    F_int(sctr) = F_int(sctr) + fe;
    
    % Assemble KT triplets using vectorized indexing
    range = count + (1:nz_per_elem);
    I(range) = sctr(ii_base(:));
    J(range) = sctr(jj_base(:));
    V(range) = KT_global(:);
    count = count + nz_per_elem;
end

KT = sparse(I(1:count), J(1:count), V(1:count), nDofs, nDofs);

end
