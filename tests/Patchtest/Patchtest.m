% Test_Patch_Verification.m
clear; clc;

fprintf('================================================\n');
fprintf('      ISOPARAMETRIC ELEMENT PATCH TEST          \n');
fprintf('================================================\n');

% --- 1. Define Test Cases (1, 4, 16 Elements) ---
cases = [1, 2, 4]; % nDiv (1x1, 2x2, 4x4)

for k = 1:length(cases)
    nDiv = cases(k);
    fprintf('\n>>> Running Case %d: %dx%d Elements (%d Nodes)\n', ...
        k, nDiv, nDiv, (nDiv+1)^2);
    
    % A. Generate Mesh
    [nodes, elements, bnd_nodes, int_nodes] = getPatchMesh(nDiv);
    
    % B. Setup FEA Model
    E = 200e9; nu = 0.3; t = 0.01;
    Model = FEM_Preprocessor_v2(E, nu, t);
    
    % Inject Mesh directly
    Model.Mesh.Nodes = nodes;
    Model.Mesh.Elements = elements;
    Model.Mesh.Normals = repmat([0 0 1], size(nodes,1), 1); % Flat plate normal Z
    
    % C. Apply Boundary Conditions (Dirichlet)
    % We fix ALL boundary nodes to the theoretical exact value.
    % If the element passes, internal nodes will settle at the exact value.
    
    for i = 1:length(bnd_nodes)
        nid = bnd_nodes(i);
        x = nodes(nid, 1);
        y = nodes(nid, 2);
        
        [u_exact, v_exact] = getTheoreticalDisp(x, y);
        
        % Fix U (DOF 1), V (DOF 2), and clean rotations (DOF 3-6 fixed to 0 for membrane test)
        Model.addBC(nid, 1, u_exact, 'Support');
        Model.addBC(nid, 2, v_exact, 'Support');
        Model.addBC(nid, 3:6, 0, 'Support'); % Fix Rotations/Z to prevent mechanism
    end
    
    % Also fix Z/Rotations for internal nodes for pure membrane patch test
    if ~isempty(int_nodes)
        Model.addBC(int_nodes, 3:6, 0, 'Support'); 
    end

    % D. Solve (Linear Static)
    Solver = FEM_Solver(Model);
    
    % We need a solveStatic method in your class. 
    % If you only have solveNonLinear, use 1 step, linear mode.
    % Assuming solveStatic exists:
    Solver.solveStaticDisplacement(); 
    
    % E. Verify Results
    verifyResults(Solver, nodes, int_nodes);
end

% ---------------------------------------------------------
% Helper Functions
% ---------------------------------------------------------

function [u, v] = getTheoreticalDisp(x, y)
    % Linear field = Constant Strain
    scale = 1e-3;
    u = scale * (2*x + y);
    v = scale * (x + 2*y);
end

function verifyResults(Solver, nodes, int_nodes)
    U_fem = Solver.U;
    max_error = 0;
    
    fprintf('    Node |      X         Y      |    U_fem      U_exact   |    V_fem      V_exact   |   Error\n');
    fprintf('    ------------------------------------------------------------------------------------------\n');
    
    % Check all nodes (Boundary should be exact match, Internal is the real test)
    check_nodes = 1:size(nodes,1); 
    
    for i = 1:length(check_nodes)
        nid = check_nodes(i);
        x = nodes(nid, 1);
        y = nodes(nid, 2);
        
        [u_ex, v_ex] = getTheoreticalDisp(x, y);
        
        u_fem = U_fem( (nid-1)*6 + 1 );
        v_fem = U_fem( (nid-1)*6 + 2 );
        
        err = sqrt((u_fem - u_ex)^2 + (v_fem - v_ex)^2);
        max_error = max(max_error, err);
        
        % Print only internal nodes (the critical ones)
        if ismember(nid, int_nodes)
            type = 'INT';
        else
            type = 'BND';
        end
        
        if ismember(nid, int_nodes) || i < 5 % Print a few to show
             fprintf('    %3d  | %8.4f %8.4f | %10.7f %10.7f | %10.7f %10.7f | %8.2e (%s)\n', ...
                nid, x, y, u_fem, u_ex, v_fem, v_ex, err, type);
        end
    end
    
    fprintf('    ------------------------------------------------------------------------------------------\n');
    if max_error < 1e-10
        fprintf('    [PASS] Maximum Displacement Error: %e ( < 1e-10 )\n', max_error);
    else
        fprintf('    [FAIL] Maximum Displacement Error: %e (Too High!)\n', max_error);
    end
    
    % Stress Check (Optional - requires stress recovery)
    % Theoretical Stress:
    % D = E/(1-nu^2) * [1 nu 0; nu 1 0; 0 0 (1-nu)/2]
    % eps = [2e-3; 2e-3; 2e-3]
    % Check if your solver stores stress somewhere.
end

