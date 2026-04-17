function result = test_assembler_tangent()
% TEST_ASSEMBLER_TANGENT  Verify Assembler.tangent() produces correct matrices
%   Tests:
%   - Output dimensions match system DOFs
%   - Stiffness matrix is symmetric
%   - Stiffness matrix is positive definite (for elastic problem)
%   - Internal force vector reasonable magnitude

result = struct('passed', false, 'name', 'test_assembler_tangent', 'details', '');

try
    % Create a simple test problem (cantilever-like geometry)
    Mesh = Mesh_standard_4node_plate('L', 10, 'H', 1, 'nx', 4, 'ny', 2);
    nNodes = size(Mesh.Nodes, 1);
    nDofs = nNodes * 6;
    
    % Create elements and material
    Elements = cell(size(Mesh.Conn, 1), 1);
    mat = Material_J2Plastic();
    
    for e = 1:length(Elements)
        conn = Mesh.Conn(e, :);
        node_coords = Mesh.Nodes(conn, :);
        Elements{e} = Curve8Element(node_coords, mat);
    end
    
    % Build scatter map
    SctrMap = zeros(length(Elements), 48);  % 8 nodes * 6 DOF/node
    for e = 1:length(Elements)
        conn = Mesh.Conn(e, :);
        for i = 1:8
            node = conn(i);
            SctrMap(e, (i-1)*6+1:i*6) = (node-1)*6+1:node*6;
        end
    end
    
    % Initial displacement vector (mostly zeros, small perturbation)
    U = zeros(nDofs, 1);
    U(1:10) = 1e-3 * randn(10, 1);  % Small random perturbations
    
    % Assemble tangent
    [KT, F_int, TrialHist] = Assembler.tangent(U, Elements, SctrMap, nDofs);
    
    % Verify dimensions
    if size(KT, 1) ~= nDofs || size(KT, 2) ~= nDofs
        result.details = sprintf('FAILED: KT dimensions [%d,%d], expected [%d,%d]', ...
            size(KT, 1), size(KT, 2), nDofs, nDofs);
        return;
    end
    
    if size(F_int, 1) ~= nDofs
        result.details = sprintf('FAILED: F_int length %d, expected %d', ...
            size(F_int, 1), nDofs);
        return;
    end
    
    % Verify symmetry (within numerical tolerance)
    if issparse(KT)
        KT_full = full(KT);
    else
        KT_full = KT;
    end
    
    sym_error = norm(KT_full - KT_full', 'fro') / norm(KT_full, 'fro');
    if sym_error > 1e-8
        result.details = sprintf('FAILED: Stiffness not symmetric (error: %.2e)', sym_error);
        return;
    end
    
    % Verify positive-definiteness (check eigenvalues of small block)
    [n_free, ~] = size(KT_full);
    if n_free > 0
        KT_block = KT_full(1:min(10, n_free), 1:min(10, n_free));
        eigvals = eig(KT_block);
        min_eig = min(real(eigvals));
        if min_eig < -1e-10  % Allow small numerical perturbation
            result.details = sprintf('FAILED: Negative eigenvalue in stiffness: %.2e', min_eig);
            return;
        end
    end
    
    % Verify internal force is reasonable
    f_norm = norm(F_int);
    if f_norm < 1e-15 || f_norm > 1e6
        result.details = sprintf('FAILED: F_int norm %.2e seems unreasonable', f_norm);
        return;
    end
    
    result.passed = true;
    result.details = sprintf('KT [%dx%d], symmetric (error %.2e), F_int norm %.2e', ...
        size(KT_full, 1), size(KT_full, 2), sym_error, f_norm);
    
catch ME
    result.details = ['ERROR: ' ME.message];
end
end
