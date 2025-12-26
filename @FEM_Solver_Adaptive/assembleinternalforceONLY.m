function  F_int = assembleinternalforceONLY(obj,U_trial)
% Assembles Global F_int based on the U_trial for line search procedure
nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
% Use triplet assembly for speed
nElems = size(obj.Model.Mesh.Elements, 1);
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
        u_el((n-1)*6 + (1:6)) = U_trial(g_dof + (1:6));
        sctr((n-1)*6 + (1:6)) = g_dof + (1:6);
    end
    elObj = Curve8Element_NL(el_nodes, el_norms, ...
        obj.Model.Material.t, obj.Model.Material.E, obj.Model.Material.nu);

    % CALL THE NEW ELEMENT METHOD
    fe = elObj.computeGlobalForceONLY(u_el); % using the same routine to transfrom 5DOFs-->6DOFs
    % Assemble F_int
    F_int(sctr) = F_int(sctr) + fe;
end
end