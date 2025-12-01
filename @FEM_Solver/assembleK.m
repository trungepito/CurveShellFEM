function assembleK(obj)
fprintf('Assembling Global Stiffness Matrix...\n');
m = obj.Model.Mesh;
mat=obj.Model.Material;
numNodes = size(m.Nodes,1);
numElems=size(m.Elements,1);
nTotalDofs = numNodes * 6;


% Allocate sparse matrix triplet arrays for speed
% 40x40 = 1600 entries per element
nz_per_elem = 48*48;
% total_nz = nElems * nz_per_elem;
estnz = int32(0.3*nz_per_elem* numElems);
I_idx = zeros(estnz, 1);
J_idx = zeros(estnz, 1);
V_val = zeros(estnz, 1);
count = 0;

for e = 1:numElems
    % Gather element data
    node_indices = m.Elements(e, :);
    el_coords = m.Nodes(node_indices, :);
    el_normals = m.Normals(node_indices, :);

    % Instantiate Element
    % (Requires Curve8Element.m in path)
    elemObj = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu);

    % Compute Ke
    % Ke = elemObj.computeStiffnessMatrix();
    Ke = elemObj.computeGlobalMatrix6DOF();
    % Map Local DOFs to Global DOFs
    sctr = zeros(1, 48);
    for n = 1:8
        start_dof = (node_indices(n) - 1) * 6;
        local_start = (n - 1) * 6;
        sctr(local_start+1 : local_start+6) = start_dof + (1:6);
    end

    % Flatten into triplets
    [ii,jj]=meshgrid(sctr,sctr);
    range = count + (1:nz_per_elem);
    I_idx(range) = ii(:);
    J_idx(range) = jj(:);
    V_val(range) = Ke(:);
    count = count + nz_per_elem;
end

% Create Sparse Matrix
obj.GlobalK = sparse(I_idx(1:count), J_idx(1:count), V_val(1:count), nTotalDofs, nTotalDofs);
fprintf('Assembly Done. DOFs: %d\n', nTotalDofs);
end