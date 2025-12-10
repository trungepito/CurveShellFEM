function assembleK(obj)
fprintf('Assembling Global Stiffness Matrix...\n');
m = obj.Model.Mesh;
mat=obj.Model.Material;
numNodes = size(m.Nodes,1);
numElems=size(m.Elements,1);
nTotalDofs = numNodes * 6;

if numElems<5e6
    % Allocate sparse matrix triplet arrays for speed
    % 40x40 = 1600 entries per element
    tic
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
    obj.GlobalK = sparse(I_idx(1:count), J_idx(1:count), V_val(1:count), nTotalDofs, nTotalDofs);
    toc
else
    % numElems = size(m.Elements,1);
    % nz_per_elem = 48*48;            % or actual nonzeros per element
    tic
    Icell = cell(numElems,1);
    Jcell = cell(numElems,1);
    Vcell = cell(numElems,1);

    % Make large read-only data constant to avoid broadcasting overhead
    mConst = parallel.pool.Constant(m);
    matConst = parallel.pool.Constant(mat);

    parfor e = 1:numElems
        mloc = mConst.Value;
        matloc = matConst.Value;

        node_indices = mloc.Elements(e, :);
        el_coords = mloc.Nodes(node_indices, :);
        el_normals = mloc.Normals(node_indices, :);

        elemObj = Curve8Element(el_coords, el_normals, matloc.t, matloc.E, matloc.nu);
        Ke = elemObj.computeGlobalMatrix6DOF();

        sctr = zeros(1, 48);
        for n = 1:8
            start_dof = (node_indices(n) - 1) * 6;
            local_start = (n - 1) * 6;
            sctr(local_start+1 : local_start+6) = start_dof + (1:6);
        end

        [ii,jj] = meshgrid(sctr,sctr);
        Icell{e} = ii(:);
        Jcell{e} = jj(:);
        Vcell{e} = Ke(:);
    end

    % Serial concatenation (single-threaded)
    I_idx = vertcat(Icell{:});
    J_idx = vertcat(Jcell{:});
    V_val = vertcat(Vcell{:});
    obj.GlobalK = sparse(I_idx, J_idx, V_val, nTotalDofs, nTotalDofs);
    toc
end
% Create Sparse Matrix

fprintf('Assembly Done. DOFs: %d\n', nTotalDofs);
end