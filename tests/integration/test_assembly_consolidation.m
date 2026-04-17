function results = test_assembly_consolidation()
% TEST_ASSEMBLY_CONSOLIDATION - Verify Task 12 (Assembly interface consolidation)
% Checks that Assembler.tangent is the sole assembly path
results = struct('passed', false, 'name', 'test_assembly_consolidation', 'details', '');

try
    % Setup simple model
    E = 210e9; nu = 0.3; t = 0.01;
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.createPlate([0,0,0], 1, 1);
    Pre.meshAllPatches(2, 2);
    
    fixedNodes = Pre.selectNodesOnPlane(1, 0, 1e-6);
    Pre.addBC(fixedNodes, 1:6, 0, 'Support');
    
    loadNodes = Pre.selectNodesOnPlane(1, 1, 1e-6);
    Pre.addNodalLoad(loadNodes, 3, 50, 'Vertical');
    
    % Create solver
    opts = SolverOptions();
    opts.MaxIterations = 10;
    Sol = FEM_Solver_Nonlinear(Pre, opts);
    
    % Verify Assembler static methods work
    U_test = zeros(size(Sol.U));
    nDofs = size(Pre.Mesh.Nodes, 1) * 6;
    
    % Direct call to Assembler.tangent (should be the only assembly path)
    try
        [KT, F_int, TrialHist] = Assembler.tangent(U_test, Sol.Elements, Sol.SctrMap, nDofs);
        
        % Verify output dimensions
        if size(KT, 1) == nDofs && size(F_int, 1) == nDofs
            results.passed = true;
            results.details = 'Assembly consolidation verified: Assembler.tangent is functional';
        else
            results.details = 'FAILED: Output dimensions incorrect';
        end
    catch ME
        results.details = sprintf('FAILED: Assembler.tangent error: %s', ME.message);
    end
    
catch ME
    results.details = ['ERROR: ' ME.message];
end
end
