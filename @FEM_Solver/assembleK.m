function assembleK(obj)
fprintf('Assembling Global Stiffness Matrix...\n');
m = obj.Model.Mesh;
mat=obj.Model.Material;
numNodes = size(m.Nodes,1);
numElems=size(m.Elements,1);
nTotalDofs = numNodes * 5;


% Allocate sparse matrix triplet arrays for speed
% 40x40 = 1600 entries per element
estnz = 1600 * numElems;
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
    Ke = elemObj.computeStiffnessMatrix();

    % Map Local DOFs to Global DOFs
    sctr = zeros(1, 40);
    for n = 1:8
        globalNode = node_indices(n);
        start_dof = (globalNode - 1) * 5;
        local_start = (n - 1) * 5;
        sctr(local_start+1 : local_start+5) = start_dof + (1:5);
    end

    % Flatten into triplets
    for r = 1:40
        for c = 1:40
            count = count + 1;
            I_idx(count) = sctr(r);
            J_idx(count) = sctr(c);
            V_val(count) = Ke(r,c);
        end
    end
end

% Create Sparse Matrix
obj.GlobalK = sparse(I_idx(1:count), J_idx(1:count), V_val(1:count), nTotalDofs, nTotalDofs);
fprintf('Assembly Done. DOFs: %d\n', nTotalDofs);
end