function assembleKg(obj)
% Loops over elements, creates Curve8Element, adds Kg to GlobalKg
fprintf('Assembling Geometric Stiffness Matrix (Kg)...\n');
m=obj.Model.Mesh;
mat=obj.Model.Material;
numNodes = numel(m.Nodes,1);
numElems=numel(m.Elements,1);
nTotalDofs = numNodes * 5;

% Kg Assembly
% Requires obj.Displacements to be populated from a static run first!
if isempty(obj.U)
    error('Must run static solve() before buckling analysis to establish stress state.');
end

estnz = 1600 * size(m.Elements, 1);
I_idx = zeros(estnz, 1); J_idx = zeros(estnz, 1); V_val = zeros(estnz, 1);
count = 0;

for e = 1:numElems
    idx = m.Elements(e, :);
    el_coords = m.Nodes(idx, :);
    el_normals = m.Normals(idx, :);

    % Gather Displacements
    u_el = zeros(40,1);
    for n = 1:8
        g_node = idx(n);
        u_el((n-1)*5 + (1:5)) = obj.U((g_node-1)*5 + (1:5));
    end

    elemObj = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu);
    Kg_e = elemObj.computeGeometricStiffness(u_el);

    % Scatter
    sctr = zeros(1,40);
    for n=1:8, sctr((n-1)*5+(1:5)) = (idx(n)-1)*5 + (1:5); end

    for r=1:40
        for c=1:40
            count=count+1;
            I_idx(count)=sctr(r); J_idx(count)=sctr(c); V_val(count)=Kg_e(r,c);
        end
    end
end
obj.GlobalKg = sparse(I_idx(1:count), J_idx(1:count), V_val(1:count), nTotalDofs, nTotalDofs);
fprintf('Assembly Kg Done. DOFs: %d\n', nTotalDofs);
end