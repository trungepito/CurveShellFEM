function assembleK(obj)
% ASSEMBLEK - Assembles the Global Stiffness Matrix (Sparse).
%
% v3.0: Standardized single-thread CPU assembly using sparse triplet indexing.
% Removed parfor to ensure predictability and zero overhead for small-to-medium meshes.
%
% See also: FEM_Solver, buildElementCache
fprintf('Assembling Global Stiffness Matrix...\n');
m = obj.Model.Mesh;
numNodes = size(m.Nodes,1);
numElems = size(m.Elements,1);
nTotalDofs = numNodes * 6;

% 1. Allocate sparse matrix triplet arrays
% 48x48 = 2304 entries per element
tick = tic;
nz_per_elem = 48*48;
estnz = nz_per_elem * numElems; % double by default
I_idx = zeros(estnz, 1);
J_idx = zeros(estnz, 1);
V_val = zeros(estnz, 1);

% 2. Pre-compute local index grid once (SK-04)
[ii_base, jj_base] = ndgrid(1:48, 1:48);
ii_base = ii_base(:);
jj_base = jj_base(:);

% 3. Assembly loop
count = 0;
for e = 1:numElems
    % Use cached element and scatter map
    elemObj = obj.Elements{e};
    Ke = elemObj.computeGlobalMatrix6DOF();
    sctr = obj.SctrMap(e, :);

    % Flatten into triplets via pre-computed mapping
    range = count + (1:nz_per_elem);
    I_idx(range) = sctr(ii_base);
    J_idx(range) = sctr(jj_base);
    V_val(range) = Ke(:);
    count = count + nz_per_elem;
end

% 4. Create Sparse Matrix
obj.GlobalK = sparse(I_idx(1:count), J_idx(1:count), V_val(1:count), nTotalDofs, nTotalDofs);
t_elapsed = toc(tick);

fprintf('Assembly Done. DOFs: %d. Time: %.4f s\n', nTotalDofs, t_elapsed);
end