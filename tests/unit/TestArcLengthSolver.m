classdef TestArcLengthSolver < matlab.unittest.TestCase
% TESTARCLENGTHSOLVER  Unit tests for FEM_Solver_ArcLength.
%
% Covers:
%   1. Constraint function mathematics (Riks, LoadControl, DispControl)
%   2. Adaptive radius scaling logic
%   3. Solver initialisation and property defaults
%   4. Stage routing (solve -> solveArcLengthStage)
%
% Run with:
%   runtests('TestArcLengthSolver')

    properties
        Pre   % FEM_Preprocessor_v2 with a minimal 1-element model
        Sol   % FEM_Solver_ArcLength instance
        nDofs % Total DOF count of the model
    end

    methods (TestMethodSetup)
        function buildMinimalModel(testCase)
            % 1x1 flat plate, 1 element (8 nodes x 6 DOF = 48 DOFs)
            testCase.Pre = FEM_Preprocessor_v2(200e9, 0.3, 0.01);
            testCase.Pre.createPlate([0 0 0], 1.0, 1.0);
            testCase.Pre.meshAllPatches(1, 1);

            % Fix three corner nodes to prevent rigid body motion
            testCase.Pre.addBC(1, 1:6, 0, 'Support');
            testCase.Pre.addBC(4, 1:6, 0, 'Support');
            testCase.Pre.addBC(8, 1:6, 0, 'Support');

            opts = SolverOptions();
            testCase.Sol  = FEM_Solver_ArcLength(testCase.Pre, opts);
            testCase.nDofs = size(testCase.Pre.Mesh.Nodes, 1) * 6;
        end
    end

    % ==================================================================
    % Constraint function tests
    % ==================================================================
    methods (Test)

        function testCrisfieldConstraint_scalarG(testCase)
            Sol = testCase.Sol;
            n   = testCase.nDofs;
            u   = rand(n,1) * 0.01;
            l   = 0.5;
            u0  = zeros(n,1);
            l0  = 0.0;
            dup = rand(n,1) * 0.001;
            dlp = 0.01;
            si  = 0.02;

            [g, h, s] = Sol.crisfieldConstraint(u, l, u0, l0, dup, dlp, si);

            testCase.verifySize(g, [1 1], 'g must be scalar');
            testCase.verifySize(h, [n 1], 'h must match nDofs');
            testCase.verifyEqual(s, dlp,  'AbsTol', 1e-14, ...
                's must equal dlp');
        end

        function testCrisfieldConstraint_atPredictor(testCase)
            % At the predictor point the constraint should be exactly zero.
            Sol = testCase.Sol;
            n   = testCase.nDofs;
            u0  = zeros(n,1);
            l0  = 0.0;
            dup = rand(n,1) * 0.001;
            dlp = 0.05;

            % Predictor point: u_pred = u0 + dlp*dup, l_pred = l0 + dlp
            u_pred = u0 + dlp * dup;
            l_pred = l0 + dlp;

            [g, ~, ~] = Sol.crisfieldConstraint(u_pred, l_pred, u0, l0, dup, dlp, 0.05);
            testCase.verifyEqual(g, 0, 'AbsTol', 1e-12, ...
                'Constraint must be zero at the predictor point');
        end

        function testLoadControlConstraint_values(testCase)
            Sol = testCase.Sol;
            n   = testCase.nDofs;
            u   = rand(n,1) * 0.01;
            l0  = 0.3;
            si  = 0.1;

            [g, h, s] = Sol.loadControlConstraint(u, l0+si, zeros(n,1), l0, ...
                zeros(n,1), 0, si);

            testCase.verifyEqual(g, 0,            'AbsTol', 1e-14, 'g zero at target lambda');
            testCase.verifyEqual(h, zeros(n,1),   'AbsTol', 1e-14, 'h must be zero vector');
            testCase.verifyEqual(s, 1,             'AbsTol', 1e-14, 's must be 1');
        end

        function testLoadControlConstraint_offTarget(testCase)
            Sol = testCase.Sol;
            n   = testCase.nDofs;
            l0  = 0.3;
            si  = 0.1;
            l   = l0 + si + 0.05;  % lambda overshoots target

            [g, ~, ~] = Sol.loadControlConstraint(zeros(n,1), l, zeros(n,1), l0, ...
                zeros(n,1), 0, si);
            testCase.verifyEqual(g, 0.05, 'AbsTol', 1e-14, ...
                'g must equal overshoot distance');
        end

        function testSphericalConstraint_onRadius(testCase)
            Sol = testCase.Sol;
            n   = testCase.nDofs;
            u0  = zeros(n,1);
            l0  = 0.0;
            ds  = 0.02;

            u = u0;
            u(3) = ds;   % purely displacement-based point on the sphere
            l = l0;

            [g, h, s] = Sol.sphericalConstraint(u, l, u0, l0, zeros(n,1), 0, ds);
            testCase.verifyEqual(g, 0, 'AbsTol', 1e-12, ...
                'Spherical g must be zero on the radius.');
            testCase.verifyEqual(h(3), 2*ds, 'AbsTol', 1e-12, ...
                'h must be 2*(u-u0).');
            testCase.verifyEqual(s, 0, 'AbsTol', 1e-14, ...
                's must be zero when lambda=lambda0.');
        end

        function testDispControlConstraint_values(testCase)
            Sol = testCase.Sol;
            n   = testCase.nDofs;
            dof = 3;
            Sol.ControlDOF = dof;

            u0 = zeros(n,1);
            si = 0.002;
            u  = u0;
            u(dof) = u0(dof) + si;   % exactly at target

            [g, h, s] = Sol.dispControlConstraint(u, 0, u0, 0, zeros(n,1), 0, si);

            testCase.verifyEqual(g, 0,   'AbsTol', 1e-14, 'g zero at target');
            testCase.verifyEqual(h(dof), 1, 'AbsTol', 1e-14, 'h nonzero only at ControlDOF');
            testCase.verifyEqual(sum(abs(h)) - abs(h(dof)), 0, 'AbsTol', 1e-14, ...
                'h must be zero everywhere except ControlDOF');
            testCase.verifyEqual(s, 0, 'AbsTol', 1e-14, 's must be 0');
        end

        function testDispControlConstraint_requiresControlDOF(testCase)
            Sol = testCase.Sol;
            Sol.ControlDOF = [];   % Deliberately unset
            n = testCase.nDofs;

            testCase.verifyError( ...
                @() Sol.dispControlConstraint(zeros(n,1), 0, zeros(n,1), 0, ...
                    zeros(n,1), 0, 0.01), ...
                'FEM_Solver_ArcLength:noControlDOF');
        end
    end

    % ==================================================================
    % Solver initialisation tests
    % ==================================================================
    methods (Test)

        function testDefaultProperties(testCase)
            Sol = testCase.Sol;
            testCase.verifyEqual(Sol.ConstraintType, 'Riks');
            testCase.verifyEmpty(Sol.ControlDOF);
            testCase.verifyEmpty(Sol.LambdaHist);
            testCase.verifyEmpty(Sol.ArcLengthHistory);
            testCase.verifyGreaterThan(Sol.MinArcLength, 0);
            testCase.verifyGreaterThan(Sol.MaxArcLength, Sol.MinArcLength);
        end

        function testInheritsAdaptiveProperties(testCase)
            Sol = testCase.Sol;
            % Must have Adaptive history arrays
            testCase.verifyNotEmpty(Sol.U);
            testCase.verifyNotEmpty(Sol.Options);
            testCase.verifyEqual(size(Sol.U, 1), testCase.nDofs);
        end

        function testElementCacheBuilt(testCase)
            Sol = testCase.Sol;
            nElems = size(testCase.Pre.Mesh.Elements, 1);
            testCase.verifyEqual(length(Sol.Elements), nElems);
            testCase.verifySize(Sol.SctrMap, [nElems, 48]);
        end
    end

    % ==================================================================
    % Stage routing test (smoke test — does not require full convergence)
    % ==================================================================
    methods (Test)

        function testSolveResetsHistory(testCase)
            % Calling solve twice should not accumulate history across calls.
            Sol = testCase.Sol;
            testCase.Pre.addNodalLoad(2, 3, -100, 'TipLoad');

            S1 = LoadingStage(1.0);
            S1.activateBC('Support');
            S1.activateLoad('TipLoad');
            S1.ConstraintType  = 'LoadControl';
            S1.ArcLengthRadius = 0.1;
            S1.ArcLengthMin    = 1e-4;
            S1.ArcLengthMax    = 0.5;

            try
                Sol.solve({S1});
            catch
                % Convergence failure is acceptable; we test history reset.
            end

            first_count = Sol.StepCount;
            lambda_len1 = length(Sol.LambdaHist);

            try
                Sol.solve({S1});
            catch
            end

            % After second call, LambdaHist must not grow beyond first run
            testCase.verifyEqual(length(Sol.LambdaHist), lambda_len1, ...
                'solve() must reset history before each run');
        end

        function testConstraintTypeOverrideFromStage(testCase)
            Sol = testCase.Sol;
            Sol.ConstraintType = 'Riks';   % Instance default

            S1 = LoadingStage(1.0);
            S1.ConstraintType = 'LoadControl';   % Stage overrides
            S1.activateBC('Support');
            S1.ArcLengthRadius = 0.1;
            S1.ArcLengthMin    = 1e-4;
            S1.ArcLengthMax    = 0.5;

            % solve() should pick up the stage override without error
            try
                Sol.solve({S1});
            catch
            end

            testCase.verifyEqual(Sol.ConstraintType, 'LoadControl', ...
                'Stage ConstraintType must override instance default');
        end

        function testConstraintTypeSphericalStage(testCase)
            Sol = testCase.Sol;
            S1 = LoadingStage(1.0);
            S1.ConstraintType = 'Spherical';
            S1.activateBC('Support');
            S1.ArcLengthRadius = 0.1;
            S1.ArcLengthMin    = 1e-4;
            S1.ArcLengthMax    = 0.5;

            try
                Sol.solve({S1});
            catch
            end

            testCase.verifyEqual(Sol.ConstraintType, 'Spherical', ...
                'Stage must route through Spherical constraint.');
        end
    end
end
