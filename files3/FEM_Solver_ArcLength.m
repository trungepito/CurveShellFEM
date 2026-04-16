classdef FEM_Solver_ArcLength < FEM_Solver_Adaptive
% FEM_SOLVER_ARCLENGTH  Adaptive arc-length solver with modular constraints.
%
% Enhancement log (P1.1, P1.3, P1.4, P2.1, P2.2, P3.1, P3.3, P4.1, P4.2):
%   See arcLengthStep.m and solveArcLengthStage.m for full details.
%
% New property:
%   fixedDofsCache_ALS  — cached fixed-DOF indices for the elastic fast path
%                          (P4.1).  Populated at stage start; used in
%                          arcLengthStep to zero fixed-DOF residual rows
%                          without re-calling the full assembly closure.

    properties
        ConstraintType = 'Riks'
        ControlDOF     = []

        ArcLengthHistory = []
        LambdaHist       = []

        MinArcLength = 1e-6
        MaxArcLength = 1.0
        ArcLengthPsi = 1.0

        % P4.1: fixed-DOF cache so arcLengthStep can zero residual rows
        % on the elastic fast path without calling the assembly closure.
        fixedDofsCache_ALS = []
    end

    methods
        function obj = FEM_Solver_ArcLength(preObj, Options)
            obj@FEM_Solver_Adaptive(preObj, Options);
            obj.LambdaHist       = [];
            obj.ArcLengthHistory = [];
        end
    end

    methods
        solve(obj, StageList)
        success = solveArcLengthStage(obj, Stage, s)
    end

    methods (Access = private)
        [u, lambda, F_int, TrialHist, converged, iters] = arcLengthStep(obj, ...
            funcHandle, constraintFn, free_dofs, ...
            u0, lambda0, dup_prev, ...
            arc_length, usePredictor, tol, maxit)
    end

    methods
        % Constraint functions (public for unit testing)
        function [g, h, s] = crisfieldConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % Dispatches to the enhanced implementation in crisfieldConstraint.m
            [g, h, s] = crisfieldConstraint(obj, u, lambda, u0, lambda0, dup, dlp, arc_length);
        end

        function [g, h, s] = loadControlConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            lambda_target = lambda0 + arc_length;
            g = lambda - lambda_target;
            h = zeros(length(u), 1);
            s = 1;
        end

        function [g, h, s] = dispControlConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            if isempty(obj.ControlDOF)
                error('FEM_Solver_ArcLength:noControlDOF', ...
                    'Set ControlDOF before using DispControl constraint.');
            end
            dof    = obj.ControlDOF;
            g      = u(dof) - (u0(dof) + arc_length);
            h      = zeros(length(u), 1);
            h(dof) = 1;
            s      = 0;
        end
    end
end
