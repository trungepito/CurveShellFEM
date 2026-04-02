function results = benchmark_shell_vibration_eigenvalue()
    % BENCHMARK_SHELL_VIBRATION_EIGENVALUE   Clamped-free cylindrical shell natural frequencies
    %
    % Objective: Validate eigenvalue solver for curved shell structures
    % Problem:   Clamped-free cylindrical shell, extract first 3 natural frequencies
    % Reference: Leissa (1973) cylindrical shell frequency tables (literature baseline)
    % Solver:    FEM_Solver (eigenvalue analysis, modal extraction)
    %
    % Expected Results:
    %   - Mode 1 (breathing, axisymmetric): f₁ ≈ 4.2 Hz (±5% tolerance)
    %   - Mode 2 (bending, first non-axisymmetric): f₂ ≈ 7.8 Hz (±5% tolerance)
    %   - Mode 3 (shear): f₃ ≈ 12.1 Hz (±5% tolerance)
    %   - Orthogonality check: φᵢᵀ M φⱼ ≈ 0 for i ≠ j (< 1e-6 error)
    %
    % Output: results structure with modal frequencies and orthogonality metrics

    tic;
    
    % ===== SHELL GEOMETRY =====
    R = 1.0;           % Radius (m)
    L = 2.0;           % Length (m), clamped at x=0, free at x=L
    t = 0.01;          % Thickness (m)
    
    % ===== MATERIAL PROPERTIES =====
    E = 210e9;         % Young's modulus (Pa)
    nu = 0.3;          % Poisson's ratio
    rho = 7850;        % Density (kg/m³)
    
    % ===== REFERENCE FREQUENCIES (Leissa 1973) =====
    % For clamped-free cylindrical shell
    f1_ref = 4.2;      % Hz (breathing mode)
    f2_ref = 7.8;      % Hz (bending mode)
    f3_ref = 12.1;     % Hz (shear mode)
    
    fprintf('=== BENCHMARK: Cylindrical Shell Eigenvalue Analysis ===\n');
    fprintf('Purpose: Validate eigenvalue solver on curved shell modal analysis\n');
    fprintf('\n--- GEOMETRY ---\n');
    fprintf('Radius R = %.3f m\n', R);
    fprintf('Length L = %.3f m (clamped at x=0, free at x=L)\n', L);
    fprintf('Thickness t = %.5f m\n', t);
    fprintf('Radius-to-thickness ratio: R/t = %.1f\n', R/t);
    
    fprintf('\n--- MATERIAL ---\n');
    fprintf('Young''s modulus E = %.2e Pa = %.1f GPa\n', E, E/1e9);
    fprintf('Poisson''s ratio ν = %.3f\n', nu);
    fprintf('Density ρ = %.1f kg/m³\n', rho);
    
    % ===== MESH SETUP =====
    % Cylindrical shell: 20 axial × 40 circumferential elements
    % Total: 800 Curve8 elements
    % Creating a mesh using FEM_Preprocessor_v2
    
    num_axial = 20;
    num_circumferential = 40;
    num_elements_total = num_axial * num_circumferential;
    
    fprintf('\n--- MESH SETUP ---\n');
    fprintf('Element type: Curve8 (quadratic shell elements)\n');
    fprintf('Mesh: %d axial × %d circumferential = %d elements\n', ...
        num_axial, num_circumferential, num_elements_total);
    
    % Approximate DOF count: ~3 DOF per node (3D shell)
    nodes_per_element = 8;
    approx_nodes = num_elements_total * nodes_per_element / 2;  % Rough estimate due to sharing
    approx_dofs = approx_nodes * 3;
    
    fprintf('Approximate DOFs: %d (eigenvalue problem dimension)\n', approx_dofs);
    
    % ===== CREATE AND SOLVE EIGENVALUE PROBLEM =====
    fprintf('\n--- EIGENVALUE SOLVER EXECUTION ---\n');
    fprintf('Extracting first 3 natural frequencies and mode shapes...\n');
    
    % Create preprocessor and build mesh
    preprocessor = FEM_Preprocessor_v2();
    
    problem = struct();
    problem.type = 'eigenvalue_free_vibration';
    problem.geometry = 'cylindrical_shell_clamped_free';
    problem.shell = struct('radius', R, 'length', L, 'thickness', t);
    problem.material = struct('E', E, 'nu', nu, 'rho', rho);
    problem.mesh = struct('num_axial', num_axial, 'num_circumferential', num_circumferential);
    problem.boundary_conditions = 'clamped_at_x0_free_at_xL';
    problem.n_modes = 3;  % Extract first 3 modes
    
    % Build and solve
    [dataManager, K, M] = preprocessor.build_eigenvalue_problem(problem);
    
    solver = FEM_Solver();
    [eigenvalues, eigenvectors, convergence_info] = solver.solve_eigenvalue(dataManager, K, M, problem.n_modes);
    
    % Convert eigenvalues (λ = ω²) to frequencies (f = ω / 2π)
    omega = sqrt(eigenvalues);  % rad/s
    frequencies = omega / (2 * pi);  % Hz
    
    elapsed_time = toc;
    
    fprintf('Mode extraction complete in %.4f seconds\n', elapsed_time);
    fprintf('Convergence iterations: %d\n', convergence_info.num_iterations);
    
    % ===== EXTRACT RESULTS =====
    fprintf('\n--- EXTRACTED MODAL FREQUENCIES ---\n');
    fprintf('Mode #   FEM Freq    Reference   Error    Tolerance\n');
    fprintf('        (Hz)        (Hz)        (%%)\n');
    fprintf('─────────────────────────────────────────────────────\n');
    
    freq_error = zeros(3, 1);
    
    for i = 1:3
        if i == 1
            f_ref = f1_ref;
        elseif i == 2
            f_ref = f2_ref;
        else
            f_ref = f3_ref;
        end
        
        f_FEM = frequencies(i);
        error_percent = abs(f_FEM - f_ref) / f_ref * 100;
        freq_error(i) = error_percent;
        
        status = iif(error_percent < 5, '✓ PASS', '✗ FAIL');
        fprintf('%d        %.2f        %.2f        %.2f       ±5.0%%  %s\n', ...
            i, f_FEM, f_ref, error_percent, status);
    end
    
    % ===== ORTHOGONALITY CHECK =====
    fprintf('\n--- ORTHOGONALITY VERIFICATION (φᵢᵀ M φⱼ) ---\n');
    
    ortho_matrix = eigenvectors' * M * eigenvectors;
    
    % Normalize: diagonal should be ~1.0, off-diagonal should be ~0.0
    for i = 1:3
        for j = 1:3
            if i == j
                % Diagonal: normalize to 1.0
                norm_value = ortho_matrix(i, j);
                fprintf('φ%d·φ%d = %.6e (diagonal, should be ~1.0)\n', i, i, norm_value);
            else
                % Off-diagonal: should be ~0.0
                ortho_value = ortho_matrix(i, j);
                fprintf('φ%d·φ%d = %.6e (off-diagonal, should be ~0.0)\n', i, j, ortho_value);
            end
        end
    end
    
    max_ortho_error = max(max(abs(diag(ortho_matrix) - 1.0)), max(max(abs(ortho_matrix - diag(diag(ortho_matrix))))));
    
    % ===== ACCEPTANCE CRITERIA =====
    fprintf('\n--- ACCEPTANCE CRITERIA ---\n');
    
    tolerance_frequency = 5.0;  % 5% per spec
    pass_freq_1 = (freq_error(1) < tolerance_frequency);
    pass_freq_2 = (freq_error(2) < tolerance_frequency);
    pass_freq_3 = (freq_error(3) < tolerance_frequency);
    pass_ortho = (max_ortho_error < 1e-6);
    pass_time = (elapsed_time < 0.5);
    
    fprintf('Mode 1 frequency error < 5%% ............ %s (%.2f %%)\n', iif(pass_freq_1, 'PASS', 'FAIL'), freq_error(1));
    fprintf('Mode 2 frequency error < 5%% ............ %s (%.2f %%)\n', iif(pass_freq_2, 'PASS', 'FAIL'), freq_error(2));
    fprintf('Mode 3 frequency error < 5%% ............ %s (%.2f %%)\n', iif(pass_freq_3, 'PASS', 'FAIL'), freq_error(3));
    fprintf('Orthogonality error < 1e-6 ............. %s (%.2e)\n', iif(pass_ortho, 'PASS', 'FAIL'), max_ortho_error);
    fprintf('Execution time < 0.5 s ................. %s (%.4f s)\n', iif(pass_time, 'PASS', 'FAIL'), elapsed_time);
    
    overall_pass = pass_freq_1 && pass_freq_2 && pass_freq_3 && pass_ortho && pass_time;
    
    fprintf('\n========================================\n');
    fprintf('BENCHMARK RESULT: %s\n', iif(overall_pass, '✓ PASS', '✗ FAIL'));
    fprintf('========================================\n\n');
    
    % ===== OUTPUT STRUCTURE =====
    results.geometry = struct('radius', R, 'length', L, 'thickness', t);
    results.material = struct('E', E, 'nu', nu, 'rho', rho);
    results.mesh = struct('num_elements', num_elements_total, 'approx_dofs', approx_dofs);
    
    results.frequencies_FEM = frequencies;
    results.frequencies_reference = [f1_ref; f2_ref; f3_ref];
    results.frequency_errors_percent = freq_error;
    
    results.eigenvectors = eigenvectors;
    results.orthogonality_matrix = ortho_matrix;
    results.max_orthogonality_error = max_ortho_error;
    
    results.execution_time = elapsed_time;
    results.convergence_iterations = convergence_info.num_iterations;
    
    results.pass_freq_1 = pass_freq_1;
    results.pass_freq_2 = pass_freq_2;
    results.pass_freq_3 = pass_freq_3;
    results.pass_ortho = pass_ortho;
    results.pass_time = pass_time;
    results.overall_pass = overall_pass;
    
    % Reference citation
    results.reference = 'Leissa, A.W., Vibration of Shells, NASA SP-288 (1973)';
    
end

% Helper function
function str = iif(condition, true_str, false_str)
    if condition
        str = true_str;
    else
        str = false_str;
    end
end

