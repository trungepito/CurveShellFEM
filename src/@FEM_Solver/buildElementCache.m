function buildElementCache(obj)
% BUILDELEMENTCACHE Pre-builds element objects and scatter maps
% Called once in the constructor. Avoids per-iteration creation.

m = obj.Model.Mesh;
mat = obj.Model.Material;
nElems = size(m.Elements, 1);

obj.Elements = cell(nElems, 1);
obj.SctrMap = zeros(nElems, 48);

for e = 1:nElems
    idx = m.Elements(e, :);
    el_coords = m.Nodes(idx, :);
    el_normals = m.Normals(idx, :);
    
    if isfield(mat, 'Type') && strcmp(mat.Type, 'GeometricNL')
        obj.Elements{e} = Curve8Element_GNI(el_coords, el_normals, mat.t, mat.E, mat.nu);
    elseif isfield(mat, 'Type') && strcmp(mat.Type, 'J2Plastic') && isfield(mat, 'Obj')
        % 2x2 Gauss * 5 Simpson = 20 points
        nGP = 4 * 5; 
        init_h = struct('sigma', zeros(3,1), 'eps_p', zeros(3,1), 'p', 0);
        hist = repmat(init_h, nGP, 1);
        obj.Elements{e} = Curve8Element_Plastic(el_coords, el_normals, mat.t, mat.Obj, hist);
    else
        obj.Elements{e} = Curve8Element(el_coords, el_normals, mat.t, mat.E, mat.nu);
    end

    % Pre-compute scatter indices
    sctr = zeros(1, 48);
    for n = 1:8
        start_dof = (idx(n) - 1) * 6;
        local_start = (n - 1) * 6;
        sctr(local_start+1 : local_start+6) = start_dof + (1:6);
    end
    obj.SctrMap(e, :) = sctr;
end
fprintf('Element cache built: %d elements.\\n', nElems);
end
