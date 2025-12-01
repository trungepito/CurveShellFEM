function assembleKg(obj)
% Loops over elements, creates Curve8Element, adds Kg to GlobalKg
fprintf('Assembling Geometric Stiffness Matrix (Kg)...\n');
m=obj.Model.Mesh;
mat=obj.Model.Material;
numNodes = size(m.Nodes,1);
numElems=size(m.Elements,1);
nTotalDofs = numNodes * 6;

% Kg Assembly
% Requires obj.Displacements to be populated from a static run first!
if isempty(obj.U)
    error('Must run static solve() before buckling analysis to establish stress state.');
end

nz_per_elem = 48*48;
% total_nz = nElems * nz_per_elem;
estnz = int32(0.3*nz_per_elem* numElems);
I_idx = zeros(estnz, 1);
J_idx = zeros(estnz, 1);
V_val = zeros(estnz, 1);
count = 0;

for e = 1:numElems
    idx = m.Elements(e, :);
    el_coords = m.Nodes(idx, :);
    el_normals = m.Normals(idx, :);

    % Gather Displacements
    u_el = zeros(48,1);
    for n = 1:8
        g_node = idx(n);
        u_el((n-1)*6 + (1:6)) = obj.U((g_node-1)*6 + (1:6));
    end

    elObj = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu);
    T_hybrid = elObj.Trans_T();
    u_el_l=T_hybrid*u_el;
    u_el_l(6:6:end)=[];
    per_40=blkdiag(elObj.per_5,elObj.per_5,elObj.per_5,elObj.per_5,elObj.per_5,elObj.per_5,elObj.per_5,elObj.per_5);
    u_el=per_40*u_el_l;
    Kg_e = elObj.computeGlobalMatrix6DOF(u_el); % using the same routine to transfrom 5DOFs-->6DOFs

    % Scatter
    sctr = zeros(1, 48);
    for n = 1:8
        start_dof = (idx(n) - 1) * 6;
        local_start = (n - 1) * 6;
        sctr(local_start+1 : local_start+6) = start_dof + (1:6);
    end

    % Flatten into triplets
    [ii,jj]=meshgrid(sctr,sctr);
    range = count + (1:nz_per_elem);
    I_idx(range) = ii(:);
    J_idx(range) = jj(:);
    V_val(range) = Kg_e(:);
    count = count + nz_per_elem;
end
obj.GlobalKg = sparse(I_idx(1:count), J_idx(1:count), V_val(1:count), nTotalDofs, nTotalDofs);
fprintf('Assembly Kg Done. DOFs: %d\n', nTotalDofs);
end