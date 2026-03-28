classdef TestElement < matlab.unittest.TestCase
    % TESTELEMENT Unit tests for Curve8Element implementation
    
    properties
        El
        Coords
        Normals
        Material
    end
    
    methods(TestMethodSetup)
        function setup(testCase)
            % Simple square element at origin
            testCase.Coords = [0 0 0; 1 0 0; 1 1 0; 0 1 0; 0.5 0 0; 1 0.5 0; 0.5 1 0; 0 0.5 0];
            testCase.Normals = repmat([0 0 1], 8, 1);
            testCase.Material.E = 200e9; testCase.Material.nu = 0.3; testCase.Material.t = 0.01;
            testCase.El = Curve8Element(testCase.Coords, testCase.Normals, 0.01, 200e9, 0.3);
        end
    end
    
    methods(Test)
        function testShapeFunctions(testCase)
            % Test at center (0,0)
            [N, ~] = Curve8Element.fmisoq8(0, 0);
            testCase.verifyEqual(sum(N), 1.0, 'RelTol', 1e-12);
            
            % Test at corners
            [N_c1, ~] = Curve8Element.fmisoq8(-1, -1);
            testCase.verifyEqual(N_c1(1), 1.0, 'AbsTol', 1e-12);
            testCase.verifyEqual(sum(N_c1), 1.0, 'RelTol', 1e-12);
        end
        
        function testKinematics(testCase)
            % Test Jacobian determinant for flat square
            [detJ, ~, ~, ~] = testCase.El.calculateKinematics(0, 0);
            testCase.verifyGreaterThan(detJ, 0);
            % Area of 1x1 element is 1.0. For Gauss point (0,0), detJ should relate to dA.
            % dA = detJ * d_xi * d_eta. For 8-node, it's normalized.
        end
        
        function testStiffnessSymmetry(testCase)
            Ke = testCase.El.computeStiffnessMatrix();
            % Use absolute tolerance for near-zero check since Ke has large magnitudes
            diff = max(abs(Ke - Ke'), [], 'all');
            testCase.verifyLessThan(diff, 1e-5);
        end
        
        function testPlasticForceConsistency(testCase)
            % Create Plastic element with proper dependencies
            matModel = Material_J2Plastic(200e9, 0.3, 250e6, 0);
            init_h = struct('sigma', zeros(3,1), 'eps_p', zeros(3,1), 'p', 0);
            hist = repmat(init_h, 20, 1); 
            el = Curve8Element(testCase.Coords, testCase.Normals, 0.01, 200e9, 0.3, matModel, hist);
            
            u_el = zeros(48, 1);
            [~, F_int] = el.computeGlobalMatrix6DOF(u_el);
            
            % Force should be essentially zero for zero displacement
            testCase.verifyLessThan(norm(F_int), 1e-10);
        end
    end
end
