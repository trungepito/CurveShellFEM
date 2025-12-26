function [KT, F_int] = assembleTangentSystem(obj)
% Assembles Global KT and F_int based on current obj.U
nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 6;

% Use triplet assembly for speed
nElems = size(obj.Model.Mesh.Elements, 1);
nz_per_elem= 48*48;
estnz = int32(nz_per_elem* nElems);
I = zeros(estnz, 1); J = zeros(estnz, 1); V = zeros(estnz, 1);
count = 0;

F_int = zeros(nDofs, 1);

for e = 1:nElems
    idx = obj.Model.Mesh.Elements(e, :);
    el_nodes = obj.Model.Mesh.Nodes(idx, :);
    el_norms = obj.Model.Mesh.Normals(idx, :);

    % Extract Current Element Displacement
    u_el = zeros(48, 1);
    sctr = zeros(1, 48);
    for n = 1:8
        g_dof = (idx(n)-1)*6;
        u_el((n-1)*6 + (1:6)) = obj.U(g_dof + (1:6));
        sctr((n-1)*6 + (1:6)) = g_dof + (1:6);
    end

    elObj = Curve8Element_NL(el_nodes, el_norms, ...
        obj.Model.Material.t, obj.Model.Material.E, obj.Model.Material.nu);

    % CALL THE NEW ELEMENT METHOD
    [KT_global,fe] = elObj.computeGlobalMatrix6DOF(u_el); % using the same routine to transfrom 5DOFs-->6DOFs

    % Assemble F_int
    F_int(sctr) = F_int(sctr) + fe;
    % Assemble KT triplets
    [ii,jj]=meshgrid(sctr,sctr);
    range = count + (1:nz_per_elem);
    I(range) = ii(:);
    J(range) = jj(:);
    V(range) = KT_global(:);
    count = count + nz_per_elem;
end
KT = sparse(I(1:count), J(1:count), V(1:count), nDofs, nDofs);
end