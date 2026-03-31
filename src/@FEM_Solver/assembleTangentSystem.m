function [KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)
% ASSEMBLETANGENTSYSTEM Unified assembly of Global KT, F_int, and Trial History
%
% v3.0: Standardized single-thread CPU assembly using sparse triplet indexing.
% Enforces Trial-Commit pattern by returning TrialHist without mutating state.

if nargin < 2
    U_curr = obj.U;
end

nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 6;
nElems = size(obj.Model.Mesh.Elements, 1);

% 1. Allocate sparse matrix triplet arrays
tick = tic;
nz_per_elem = 48*48;
estnz = nz_per_elem * nElems;
I = zeros(estnz, 1); J = zeros(estnz, 1); V = zeros(estnz, 1);

F_int = zeros(nDofs, 1);
TrialHist = cell(nElems, 1); % Store trial states for SK-05

% 2. Pre-compute local index grid once (SK-04)
[ii_base, jj_base] = ndgrid(1:48, 1:48);
ii_base = ii_base(:);
jj_base = jj_base(:);

% 3. Assembly loop
count = 0;
for e = 1:nElems
    sctr = obj.SctrMap(e, :);
    u_el = U_curr(sctr);

    % Call the element method (returns Global 48-DOF Ke and fe)
    elObj = obj.Elements{e};
    [KT_global, fe, NewHist] = elObj.computeGlobalMatrix6DOF(u_el);
    TrialHist{e} = NewHist;

    % Assemble F_int
    F_int(sctr) = F_int(sctr) + fe;
    
    % Assemble KT triplets
    range = count + (1:nz_per_elem);
    I(range) = sctr(ii_base);
    J(range) = sctr(jj_base);
    V(range) = KT_global(:);
    count = count + nz_per_elem;
end

% 4. Create Sparse Matrix
KT = sparse(I(1:count), J(1:count), V(1:count), nDofs, nDofs);
t_elapsed = toc(tick);

% No print here to avoid noise in nonlinear loops
end
