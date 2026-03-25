classdef FEM_Solver_ArcLength < FEM_Solver_Adaptive
% FEM_SOLVER_ARCLENGTH - Adaptive arc-length solver with modular constraints.
%
% Inherits from FEM_Solver_Adaptive for stage-based solving and event
% notifications. Integrates the Crisfield/Riks, load-control, and
% displacement-control constraint families via a modular function-handle
% pattern ported from the nonlinear arc-length sample library.
%
% The predictor-corrector loop follows the standard arc-length algorithm:
%   Predictor : solve KT * dup = fext; scale dlp by arc length
%   Corrector : augmented Newton-Raphson with constraint equation
%
% Usage:
%   opts  = SolverOptions();
%   Sol   = FEM_Solver_ArcLength(Pre, opts);
%
%   S1 = LoadingStage(1.0);
%   S1.activateBC('Support');
%   S1.activateLoad('Pressure');
%   S1.ConstraintType   = 'Riks';
%   S1.ArcLengthRadius  = 0.02;
%   S1.ArcLengthMin     = 1e-5;
%   S1.ArcLengthMax     = 0.5;
%
%   Sol.solve({S1});
%
% See also: FEM_Solver_Adaptive, LoadingStage, SolverOptions

    properties
        % --- Constraint configuration ---
        % ConstraintType and ControlDOF are read from the active LoadingStage
        % at the start of each stage, but can also be set as instance
        % defaults that stages can override.
        ConstraintType = 'Riks'  % 'Riks' | 'LoadControl' | 'DispControl'
        ControlDOF     = []      % DOF index for DispControl

        % --- Arc-length history ---
        ArcLengthHistory = []    % Scalar arc length used at each converged step
        LambdaHist       = []    % Load factor at each converged step (lambda)

        % --- Instance-level bounds (overridden per-stage if stage supplies them) ---
        MinArcLength = 1e-6
        MaxArcLength = 1.0
    end

    methods
        function obj = FEM_Solver_ArcLength(preObj, Options)
            % Constructor - delegates to FEM_Solver_Adaptive then initialises
            % arc-length-specific history arrays.
            obj@FEM_Solver_Adaptive(preObj, Options);
            obj.LambdaHist       = [];
            obj.ArcLengthHistory = [];
        end
    end

    % ------------------------------------------------------------------
    % PUBLIC INTERFACE
    % ------------------------------------------------------------------
    methods
        solve(obj, StageList)               % Override Adaptive's solve
        solveArcLengthStage(obj, Stage, s)  % Stage-level arc-length driver
    end

    % ------------------------------------------------------------------
    % INTERNAL SOLVER LOGIC  (Access = private)
    % ------------------------------------------------------------------
    methods (Access = private)
        [u, lambda, converged, iters] = arcLengthStep(obj, ...
            funcHandle, constraintFn, u0, lambda0, ...
            arc_length, usePredictor, tol, maxit)
    end

    % ------------------------------------------------------------------
    % CONSTRAINT FUNCTIONS  (public so TestSolvers can call them directly)
    % ------------------------------------------------------------------
    methods
        function [g, h, s] = crisfieldConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % CRISFIELDCONSTRAINT - Riks (spherical) arc-length constraint.
            %
            % Constrains the solution to lie on the hyperplane orthogonal to
            % the predictor direction, passing through the predictor point.
            %
            % Reference: Crisfield (1981), "A fast incremental/iterative
            % solution procedure that handles snap-through", Computers &
            % Structures, 13(1-3):55-62.
            %
            %   g = dup'*(u - u1) + dlp*(lambda - lambda1) = 0
            %
            % where u1 = u0 + dlp*dup,  lambda1 = lambda0 + dlp
            u1      = u0 + dlp * dup;
            lambda1 = lambda0 + dlp;
            g = dup' * (u - u1) + dlp * (lambda - lambda1);
            h = dup;    % dg/du
            s = dlp;    % dg/dlambda
        end

        function [g, h, s] = loadControlConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % LOADCONTROLCONSTRAINT - Load-control constraint.
            %
            % Constrains the load factor increment to a fixed value equal to
            % arc_length.  Reduces to standard incremental load stepping.
            %
            %   g = lambda - (lambda0 + arc_length) = 0
            lambda_target = lambda0 + arc_length;
            g = lambda - lambda_target;
            h = zeros(length(u), 1);  % dg/du = 0
            s = 1;                    % dg/dlambda = 1
        end

        function [g, h, s] = dispControlConstraint(obj, u, lambda, ...
                u0, lambda0, dup, dlp, arc_length)
            % DISPCONTROLCONSTRAINT - Displacement-control constraint.
            %
            % Constrains the displacement at ControlDOF to a fixed increment
            % equal to arc_length.
            %
            %   g = u(ControlDOF) - (u0(ControlDOF) + arc_length) = 0
            if isempty(obj.ControlDOF)
                error('FEM_Solver_ArcLength:noControlDOF', ...
                    'ControlDOF must be set before using DispControl constraint.');
            end
            dof          = obj.ControlDOF;
            u_target     = u0(dof) + arc_length;
            g            = u(dof) - u_target;
            h            = zeros(length(u), 1);
            h(dof)       = 1;   % dg/du(dof) = 1
            s            = 0;   % dg/dlambda = 0
        end
    end

    % ------------------------------------------------------------------
    % PROTECTED (Element cache inherited from FEM_Solver_Adaptive)
    % ------------------------------------------------------------------
    methods (Access = protected)
        buildElementCache(obj)
    end
end
