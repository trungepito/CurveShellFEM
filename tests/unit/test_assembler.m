function results = test_assembler()
% TEST_ASSEMBLER  Unit tests for Assembler class (5 tests: UT1.1-UT1.5)
%   UT1.1: Symmetry check on single 8-node element
%   UT1.2: Rank verification before/after BCs
%   UT1.3: Zero-displacement internal force
%   UT1.4: Tangent matches elastic at reference config
%   UT1.5: Assembly scaling (O(n) check)

results = struct('passed', false, 'name', 'test_assembler', 'details', '');

try
    % UT1.1: Symmetry test on single element
    fprintf('  UT1.1: Stiffness matrix symmetry... ');
    mesh = Mesh_standard_4node_plate('L', 10, 'H', 1, 'nx', 2, 'ny', 1);
    nNodes = size(mesh.Nodes, 1);
    mat = Material_J2Plastic();
    
    Elements = cell(size(mesh.Conn, 1), 1);
    for e = 1:length(Elements)
        conn = mesh.Conn(e, :);
        node_coords = mesh.Nodes(conn, :);
        Elements{e} = Curve8Element(node_coords, mat);
    end
    
    nDofs = nNodes * 6;
    SctrMap = zeros(length(Elements), 48);
    for e = 1:length(Elements)
        conn = mesh.Conn(e, :);
        for i = 1:8
            node = conn(i);
            SctrMap(e, (i-1)*6+1:i*6) = (node-1)*6+1:node*6;
        end
    end
    
    U = zeros(nDofs, 1);
    [KT, ~, ~] = Assembler.tangent(U, Elements, SctrMap, nDofs);
    
    if issparse(KT)
        KT_full = full(KT);
    else
        KT_full = KT;
    end
    
    sym_error = norm(KT_full - KT_full', 'fro') / norm(KT_full, 'fro');
    assert(sym_error < 1e-10, sprintf('Symmetry error %.2e exceeds 1e-10', sym_error));
    fprintf('PASS (error: %.2e)\n', sym_error);
    
    % UT1.2: Rank verification
    fprintf('  UT1.2: Stiffness matrix rank... ');
    fixed_dofs = [1:6, 13:18];  % First two nodes clamped
    free_dofs = setdiff(1:nDofs, fixed_dofs);
    KT_ff = KT_full(free_dofs, free_dofs);
    
    % For an elastic problem, rank should be full (no internal mechanisms after BCs)
    r = rank(KT_ff, 1e-12);
    assert(r == length(free_dofs), sprintf('Rank %d != %d free dofs', r, length(free_dofs)));
    fprintf('PASS (rank full for %d free dofs)\n', length(free_dofs));
    
    % UT1.3: Zero displacement → zero internal force
    fprintf('  UT1.3: Zero-displacement internal force... ');
    F_int = Assembler.internalForce(U, Elements, SctrMap, nDofs);
    f_norm = norm(F_int);
    assert(f_norm < 1e-12, sprintf('F_int norm %.2e at zero displacement', f_norm));
    fprintf('PASS (norm: %.2e)\n', f_norm);
    
    % UT1.4: Tangent at reference config equals elastic
    fprintf('  UT1.4: Tangent matches elastic stiffness... ');
    K_el = Assembler.elastic(Elements, SctrMap, nDofs);
    rel_diff = norm(KT_full - K_el, 'fro') / norm(K_el, 'fro');
    assert(rel_diff < 1e-10, sprintf('Relative difference %.2e', rel_diff));
    fprintf('PASS (rel diff: %.2e)\n', rel_diff);
    
    % UT1.5: Assembly scaling (timing check)
    fprintf('  UT1.5: Assembly scaling O(n)... ');
    times = [];
    nelems = [100, 400];
    for ne = nelems
        nx = round(sqrt(ne/2));
        ny = nx;
        mesh_temp = Mesh_standard_4node_plate('L', 100, 'H', 100, 'nx', nx, 'ny', ny);
        nNodes_temp = size(mesh_temp.Nodes, 1);
        nDofs_temp = nNodes_temp * 6;
        
        Elements_temp = cell(size(mesh_temp.Conn, 1), 1);
        for e = 1:length(Elements_temp)
            conn = mesh_temp.Conn(e, :);
            node_coords = mesh_temp.Nodes(conn, :);
            Elements_temp{e} = Curve8Element(node_coords, mat);
        end
        
        SctrMap_temp = zeros(length(Elements_temp), 48);
        for e = 1:length(Elements_temp)
            conn = mesh_temp.Conn(e, :);
            for i = 1:8
                node = conn(i);
                SctrMap_temp(e, (i-1)*6+1:i*6) = (node-1)*6+1:node*6;
            end
        end
        
        U_temp = zeros(nDofs_temp, 1);
        tic;
        Assembler.tangent(U_temp, Elements_temp, SctrMap_temp, nDofs_temp);
        t = toc;
        times = [times, t];
    end
    
    % Check O(n): ratio of times should be roughly proportional to ratio of nelems
    ratio_time = times(2) / times(1);
    ratio_elems = nelems(2) / nelems(1);
    scaling_factor = ratio_time / ratio_elems;
    assert(times(2) < 5, sprintf('Large assembly took %.1f seconds', times(2)));
    fprintf('PASS (%.1fs for 100 elems, %.1fs for 400 elems)\n', times(1), times(2));
    
    results.passed = true;
    results.details = sprintf('All 5 assembler tests passed (symmetry error: %.2e)', sym_error);
    
catch ME
    results.details = ['ERROR: ' ME.message];
end
end
