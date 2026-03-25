function F_int = assembleinternalforceONLY(obj, U_trial)
% ASSEMBLEINTERNALFORCEONLY Unified assembly of Global F_int for line search
% U_trial: Trial displacement vector (nDofs x 1)

nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
nElems = size(obj.Model.Mesh.Elements, 1);
F_int = zeros(nDofs, 1);

for e = 1:nElems
    sctr = obj.SctrMap(e, :);

    % Extract Trial Element Displacement using scatter map
    u_el = zeros(48, 1);
    for n = 1:8
        g_dof = (obj.Model.Mesh.Elements(e, n)-1)*6;
        u_el((n-1)*6 + (1:6)) = U_trial(g_dof + (1:6));
    end

    % Use cached element object
    elObj = obj.Elements{e};

    % CALL THE ELEMENT METHOD
    fe = elObj.computeGlobalForceONLY(u_el);
    
    % Assemble F_int
    F_int(sctr) = F_int(sctr) + fe;
end

end
