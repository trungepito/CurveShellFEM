classdef FEM_Solver_Nonlinear < FEM_Solver
% FEM_SOLVER_NONLINEAR - Unified base class for all nonlinear solvers.
%
% v3.1: Unified architecture — handles both adaptive NR and arc-length
% analysis via IncrementalStrategy pattern.
    
    properties
        Options         % Instance of SolverOptions
        Time = 0        % Current pseudo-time or load factor
        
        % Stage tracking
        F_ext_start     % External force at start of each stage
        History_Load    % Number of steps per stage
        
        % New: centralized append-only archive
        state           % SolutionState handle (or [])
        
        % Quasi-Newton (L-BFGS) history
        lbfgs_S = {}    % cell list of s_i = u_{i+1} - u_i
        lbfgs_Y = {}    % cell list of y_i = R_{i+1} - R_i
    end

    properties (Dependent)
        % Solution History (forwarding to state object)
        U_Hist          % [nDOFs x nSteps] Matrix of solutions
        History_Time    % [nSteps x 1] Vector of time/load factors
        LambdaHist      % Cumulative load factor per step
        ArcLengthHistory % Arc-length radius used per step
        ReactionHist    % Cell array of reaction forces per stage
        StepCount       % Number of successful increments
    end
    
    events
        StepConverged   % Triggered after a successful increment
    end
    
    methods
        function obj = FEM_Solver_Nonlinear(preObj, Opt)
            obj@FEM_Solver(preObj);
            if nargin < 2, Opt = SolverOptions(); end
            obj.Options = Opt;
            
            % Initialization
            nDofs = size(preObj.Mesh.Nodes,1)*6;
            obj.U = zeros(nDofs, 1);
            obj.F_ext_start = zeros(nDofs, 1);
            
            % Create SolutionState archive (I3)
            obj.state = SolutionState(nDofs, Opt);
        end

        % --- Dependent property getters ---
        function v = get.U_Hist(obj)
            v = obj.state.U_Hist(:, 1:obj.state.StepCount);
        end
        function v = get.History_Time(obj)
            % For backward compatibility, we return LambdaHist if pseudo-time isn't explicit
            v = obj.state.LambdaHist(1:obj.state.StepCount)';
        end
        function v = get.LambdaHist(obj)
            v = obj.state.LambdaHist(1:obj.state.StepCount);
        end
        function v = get.ArcLengthHistory(obj)
            v = obj.state.ArcLengthHist(1:obj.state.StepCount);
        end
        function v = get.ReactionHist(obj)
            v = obj.state.ReactionHist;
        end
        function v = get.StepCount(obj)
            v = obj.state.StepCount;
        end
    end
    
    % Public interface
    methods
        solve(obj, StageList)
    end
    
    methods (Access = protected)
        % Core Newton-Raphson Loop
        [converged, U_out, reaction, iter] = newtonLoop(obj, F_ext, U_start, fixed_dofs)
        
        % Stage drivers
        success = solveIncrementalStage(obj, Stage, strategy, s)
        
        % Deprecated: use obj.state.appendStep instead
        function updateHistory(obj, ~, U_sol)
            warning('updateHistory is deprecated. State is updated via appendStep.');
            obj.U = U_sol;
        end
    end
end
