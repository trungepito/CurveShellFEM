classdef TestSolvers < matlab.unittest.TestCase
    % TESTSOLVERS Regression tests for FEM Solvers
    
    properties
        Model
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Small 1-element plate model
            testCase.Model = FEM_Preprocessor_v2(200e9, 0.3, 0.01);
            testCase.Model.createPlate([0 0 0], 1.0, 1.0);
            testCase.Model.meshAllPatches(1, 1);
            % Fix bottom edge (X=0)
            testCase.Model.addBC(1, 1:6, 0, 'FIXED');
            testCase.Model.addBC(4, 1:6, 0, 'FIXED');
            testCase.Model.addBC(8, 1:6, 0, 'FIXED');
        end
    end
    
    methods(Test)
        function testLinearSolver(testCase)
            % Apply load at tip
            testCase.Model.addNodalLoad(2, 3, -100, 'TIP'); 
            testCase.Model.addNodalLoad(3, 3, -100, 'TIP');
            testCase.Model.addNodalLoad(6, 3, -100, 'TIP');
            
            Sol = FEM_Solver(testCase.Model);
            Sol.solveStatic();
            
            testCase.verifyNotEmpty(Sol.U);
            % Tip nodes (IDs 2,3,6) should have negative Z displacement
            testCase.verifyLessThan(Sol.U((2-1)*6 + 3), 0);
        end
        
        function testNonLinearSolver(testCase)
            % Apply larger load
            testCase.Model.addNodalLoad(2, 3, -1000, 'TIP'); 
            
            Sol = FEM_Solver_NL(testCase.Model);
            opts = SolverOptions();
            opts.numLoadSteps = 2;
            Sol.solveNonLinear(opts);
            
            testCase.verifyNotEmpty(Sol.U);
            testCase.verifySize(Sol.U, [8*6, 1]);
        end
        
        function testAdaptiveSolver(testCase)
             opts = SolverOptions();
             Sol = FEM_Solver_Adaptive(testCase.Model, opts);
             % Since solveStage is private, we can only verify initialization
             % or test through the public 'solve' method if we have a Stage
             testCase.verifyNotEmpty(Sol.U);
        end
        
        function testArcLengthConstraints(testCase)
            % Test individual constraint functions
            opts = SolverOptions();
            Sol = FEM_Solver_ArcLength(testCase.Model, opts);
            
            % Test data
            u = rand(48, 1) * 0.01;  % Small displacements
            l = 0.5;                 % Load factor
            u0 = zeros(48, 1);       % Initial displacements
            l0 = 0;                  % Initial load factor
            dup = rand(48, 1) * 0.001;  % Predictor displacement increment
            dlp = 0.01;              % Predictor load increment
            arc_length = 0.01;      % Arc length radius
            
            % Test Crisfield constraint
            [g, h, s] = Sol.crisfieldConstraint(u, l, u0, l0, dup, dlp, arc_length);
            testCase.verifySize(g, [1, 1], 'Crisfield g should be scalar');
            testCase.verifySize(h, [48, 1], 'Crisfield h should match DOF size');
            testCase.verifySize(s, [1, 1], 'Crisfield s should be scalar');
            
            % Test LoadControl constraint
            [g_lc, h_lc, s_lc] = Sol.loadControlConstraint(u, l, u0, l0, dup, dlp, arc_length);
            testCase.verifySize(g_lc, [1, 1], 'LoadControl g should be scalar');
            testCase.verifyEqual(h_lc, zeros(48, 1), 'LoadControl h should be zero');
            testCase.verifyEqual(s_lc, 1, 'LoadControl s should be 1');
            
            % Test DispControl constraint
            Sol.ControlDOF = 3;  % Z displacement of first node
            [g_dc, h_dc, s_dc] = Sol.dispControlConstraint(u, l, u0, l0, dup, dlp, arc_length);
            testCase.verifySize(g_dc, [1, 1], 'DispControl g should be scalar');
            testCase.verifyEqual(nnz(h_dc), 1, 'DispControl h should have one non-zero');
            testCase.verifyEqual(h_dc(3), 1, 'DispControl h should be 1 at control DOF');
            testCase.verifyEqual(s_dc, 0, 'DispControl s should be 0');
        end
    end
end
