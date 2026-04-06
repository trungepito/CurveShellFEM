classdef FEM_Solver_ArcLength < FEM_Solver_Adaptive
% FEM_SOLVER_ARCLENGTH  Adaptive arc-length solver with modular constraints.
%
% Inherits from FEM_Solver_Adaptive for stage-based solving and event
% notifications. Implements the Crisfield (1981) generalised arc-length
% algorithm with four constraint families: Modified Riks (Hyperplane),
% spherical arc-length, load control, and displacement control.
%
% Each constraint returns the scalar constraint function g, its gradient h
% with respect to displacements, and its gradient s with respect to the
% load factor.  The corrector Newton-Raphson then solves:
%
%   dl  = -(g + h'*du_II) / (s + h'*du_I)
%   du  =  dl * du_I + du_II
%
% where  KT * du_I = F_ext  and  KT * du_II = -R.
%
% Usage:
%   opts = SolverOptions();
%   Sol  = FEM_Solver_ArcLength(Pre, opts);
%
%   S1 = LoadingStage(1.0);
%   S1.activateBC('Support');
%   S1.activateLoad('Pressure');
%   S1.ConstraintType  = 'Riks';
%   S1.ArcLengthRadius = 0.02;
%   S1.ArcLengthMin    = 1e-5;
%   S1.ArcLengthMax    = 0.5;
%
%   Sol.solve({S1});
%
% See also: FEM_Solver_Adaptive, LoadingStage, SolverOptions

    properties
        % Constraint selection ---
        ConstraintType = 'Riks'  % 'Riks' | 'Spherical' | 'LoadControl' | 'DispControl'
        ControlDOF     = []      % Scalar DOF index required for DispControl

        % Per-step output history ---
        ArcLengthHistory = []    % Arc-length radius used at each converged step
        LambdaHist       = []    % Cumulative load factor at each converged step

        % Instance-level fallback bounds (each stage overrides these) ---
        MinArcLength = 1e-6
        MaxArcLength = 1.0
        ArcLengthPsi = 1.0  % Load-scaling factor
    end

    % ====================================================================
    methods
        function obj = FEM_Solver_ArcLength(preObj, Options)
            % Delegate to FEM_Solver_Adaptive, then initialise arc-length arrays.
            obj@FEM_Solver_Adaptive(preObj, Options);
            obj.LambdaHist       = [];
            obj.ArcLengthHistory = [];
        end
    end

    % ====================================================================
    % PUBLIC INTERFACE
    % ====================================================================
    methods
        solve(obj, StageList)
        sucess=solveArcLengthStage(obj, Stage, s)
    end

    % ====================================================================
    % INTERNAL CORE  (private — not callable from outside)
    % ====================================================================
    methods (Access = private)
        % Returns u, lambda at step end plus convergence flag and iter count.
        % Also returns F_int and TrialHist so solveArcLengthStage avoids 
        % an extra assembly or state leak.
        [u, lambda, F_int, TrialHist, converged, iters] = arcLengthStep(obj, ...
            funcHandle, constraintFn, free_dofs, ...
            u0, lambda0, dup_prev, ...
            arc_length, usePredictor, tol, maxit)
    end

    % ====================================================================
    % CONSTRAINT FUNCTIONS
    % Public access so unit tests can call them directly without a running
    % solve loop.
    % ====================================================================
    methods

        function [g, h, s] = crisfieldConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % CRISFIELDCONSTRAINT  Riks / spherical arc-length constraint.
            %
            % The solution is constrained to lie on the hyperplane normal to
            % the predictor direction through the predictor point (u1, l1):
            %
            %   g = dup'*(u - u1) + dlp*(lambda - l1) = 0
            %   u1 = u0 + dlp*dup,   l1 = lambda0 + dlp
            %
            % Ref: Crisfield (1981), Comp. & Struct. 13(1-3):55-62.
            %
            % FIX applied: when dlp = 0 (no predictor step yet) s = dlp
            % would zero the denominator in the corrector.  We fall back to
            % arc_length as the load-direction scale in that case.
            u1      = u0 + dlp * dup;
            lambda1 = lambda0 + dlp;
            % Hyperplane constraint with load scaling psi
            g = dup' * (u - u1) + obj.ArcLengthPsi^2 * dlp * (lambda - lambda1);
            h = dup;
            s = obj.ArcLengthPsi^2 * dlp;
            % Guard: if s is numerically zero use arc_length magnitude so
            % the corrector denominator (s + h'*du_I) stays well-conditioned.
            if abs(s) < 1e-14
                s = arc_length * obj.ArcLengthPsi^2;
            end
        end

        function [g, h, s] = loadControlConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % LOADCONTROLCONSTRAINT  Fixed load-factor increment per step.
            %
            %   g = lambda - (lambda0 + arc_length) = 0
            %
            % arc_length is the target load-factor increment for this step.
            % The sign of arc_length controls loading (+) vs unloading (-).
            lambda_target = lambda0 + arc_length;
            g = lambda - lambda_target;
            h = zeros(length(u), 1);   % dg/du = 0 everywhere
            s = 1;                     % dg/dlambda = 1
        end

        function [g, h, s] = sphericalConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % SPHERICALCONSTRAINT  Crisfield spherical arc-length constraint.
            %
            %   g = ||u-u0||^2 + psi^2*(lambda-lambda0)^2 - ds^2 = 0
            %
            % where ds is arc_length and psi is ArcLengthPsi.
            du = u - u0;
            dl = lambda - lambda0;
            g  = du' * du + obj.ArcLengthPsi^2 * dl^2 - arc_length^2;
            h  = 2 * du;
            s  = 2 * obj.ArcLengthPsi^2 * dl;
        end

        function [g, h, s] = dispControlConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % DISPCONTROLCONSTRAINT  Fixed displacement increment at ControlDOF.
            %
            %   g = u(dof) - (u0(dof) + arc_length) = 0
            %
            % arc_length is the signed displacement increment; negative values
            % produce unloading.
            if isempty(obj.ControlDOF)
                error('FEM_Solver_ArcLength:noControlDOF', ...
                    'Set ControlDOF before using DispControl constraint.');
            end
            dof      = obj.ControlDOF;
            g        = u(dof) - (u0(dof) + arc_length);
            h        = zeros(length(u), 1);
            h(dof)   = 1;   % dg/du(dof) = 1
            s        = 0;   % dg/dlambda = 0
        end

    end

    % ====================================================================
    % PROTECTED — element cache override
    % ====================================================================
    % methods (Access = protected)
    %     buildElementCache(obj)
    % end

end
