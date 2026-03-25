classdef BenchmarkSolvers < matlab.unittest.TestCase
    % BENCHMARKSOLVERS: Industrial validation suite for CurveShellFEM
    
    properties
        Model
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            testCase.Model = FEM_Preprocessor_v2(70e9, 0.33, 0.01);
        end
    end
    
    methods(Test)
        function testLinearCantilever(testCase)
            L = 1.0; b = 0.1; t = 0.01; P = 100;
            I = (b * t^3) / 12;
            w_analytical = (P * L^3) / (3 * testCase.Model.Material.E * I);
            
            testCase.Model.createPlate([0, -b/2, 0], L, b); 
            testCase.Model.meshAllPatches(15, 2); 
            
            ids = testCase.Model.selectNodesOnPlane(1, 0, 1e-4);
            testCase.Model.addBC(ids, 1:6, 0, 'CLAMP');
            
            tip_ids = testCase.Model.selectNodesOnPlane(1, L, 1e-4);
            testCase.Model.addNodalLoad(tip_ids, 3, -P/length(tip_ids), 'TIP');
            
            Sol = FEM_Solver(testCase.Model);
            Sol.solveStatic();
            
            w_fem = mean(abs(Sol.U((tip_ids-1)*6 + 3)));
            
            error_val = abs(w_fem - w_analytical) / w_analytical;
            testCase.verifyLessThan(error_val, 0.05, sprintf('Error %.2f%% exceeds 5%%', error_val*100));
        end
        

    end
end
