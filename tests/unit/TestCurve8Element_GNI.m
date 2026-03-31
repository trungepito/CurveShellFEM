classdef TestCurve8Element_GNI < matlab.unittest.TestCase
    % TESTCURVE8ELEMENT_GNI Unit tests for Curve8Element_GNI implementation

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
            testCase.El = Curve8Element_ANS_EAS(testCase.Coords, testCase.Normals, 0.01, 200e9, 0.3);
        end
    end

    methods(Test)
        function testInstantiation(testCase)
            % Test that element instantiates without error
            testCase.verifyNotEmpty(testCase.El);
            testCase.verifyEqual(testCase.El.Thickness, 0.01);
        end

        function testTangentStiffnessAndForce(testCase)
            % Test computeGlobalMatrix6DOF with zero displacement (calls tangent internally)
            [KT, F_int, NewHist] = testCase.El.computeGlobalMatrix6DOF(zeros(48, 1));
            testCase.verifySize(KT, [48, 48]);
            testCase.verifySize(F_int, [48, 1]);
            testCase.verifyEmpty(NewHist);  % No history for GNI
            % Internal force should be zero for zero displacement
            testCase.verifyEqual(F_int, zeros(48, 1), 'AbsTol', 1e-10);
        end

        function testNonlinearResponse(testCase)
            % Test with small displacement to check nonlinear terms
            u_global = zeros(48, 1);
            u_global(1:3) = [0.001; 0; 0];  % Small x-displacement at node 1
            [KT, F_int, ~] = testCase.El.computeGlobalMatrix6DOF(u_global);
            % Internal force should not be zero
            testCase.verifyTrue(any(abs(F_int) > 1e-12), 'Nonlinear response should produce non-zero forces');
            % KT should be symmetric
            diff = max(abs(KT - KT'), [], 'all');
            testCase.verifyLessThan(diff, 1e-5);
        end

        function testGlobalMatrix(testCase)
            % Test global matrix computation (already tested above, but explicit)
            [KT_global, F_int] = testCase.El.computeGlobalMatrix6DOF(zeros(48, 1));
            testCase.verifySize(KT_global, [48, 48]);
            testCase.verifySize(F_int, [48, 1]);
        end
    end
end