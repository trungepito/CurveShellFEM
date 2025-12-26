classdef FEM_Solver_Adaptive < FEM_Solver
    properties
        % Model           % The FEA Model (Mesh, Props)
        Options         % Instance of SolverOptions

        % State
        % U               % Current Total Displacement
        Time=0            % Current Pseudo-Time
        StepCount=0       % Integer step counter
        F_ext_start       % external for at start of each stage!

        % Optimized History Storage
        % We store results in matrices for speed: [nSteps x nDOFs]
        U_Hist       % Matrix of results
        History_Time    % Vector of time steps
        History_Load    % Vector of load factors
        ReactionHist
    end
    % --- 1. DEFINE EVENTS ---
    events
        StepConverged      % Triggered after a successful time step
        % AnalysisFinished   % Triggered at the very end
    end
    methods
        function obj = FEM_Solver_Adaptive(preObj, Options)
            obj@FEM_Solver(preObj);
            obj.Options = Options;
            obj.U = zeros(size(preObj.Mesh.Nodes,1)*6, 1);
            obj.Time = 0;
            obj.StepCount = 0;
            obj.F_ext_start=zeros(size(preObj.Mesh.Nodes,1)*6, 1);
            % Pre-allocate History (Estimate 100 steps, grow if needed)
            % Pre-allocation prevents MATLAB from resizing memory every step
            estimated_steps = 30;
            nDofs = length(obj.U);
            obj.U_Hist = zeros(nDofs,estimated_steps);
            obj.History_Time = zeros(estimated_steps, 1);
        end
    end
    methods
        % =================================================================
        % MASTER SOLVER ROUTINE
        % =================================================================
        solve(obj, StageList)
        % StageList: Cell array of LoadingStage objects
        
    end

    methods (Access = private)
        % =================================================================
        % STAGE SOLVER (Handles Time Stepping & Bisection)
        % =================================================================
        success = solveStage(obj, Stage,s)
        % =================================================================
        % NEWTON-RAPHSON CORE
        % =================================================================
        [converged, U_out, reaction,iter] = newtonLoop(obj,F_external,U_curr,fixed_dofs)
        %%%% other methods
        linesearch(obj,U_old,dU,R,F_ext_current,free_dofs)
        F_int = assembleinternalforceONLY(obj,U_trial)
        [KT, F_int] = assembleTangentSystem(obj,U_curr)
        F_glob = calculateGlobalTargetForce(obj, activeTags)
        [fixed_dofs,targets]=getDispload(obj,ActiveBCs)
    end
end