classdef FEM_Solver_Nonlinear < FEM_Solver
% FEM_SOLVER_NONLINEAR - Base class for iterative nonlinear solvers.
%
% This class centralizes the Newton-Raphson machinery, residual tracking,
% and convergence logic.
    
    properties
        Options         % Instance of SolverOptions
        Time = 0        % Current pseudo-time or load factor
        StepCount = 0   % Number of successful increments
        
        % Solution History
        U_Hist          % [nDOFs x nSteps] Matrix of solutions
        History_Time    % [nSteps x 1] Vector of time/load factors
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
            obj.U_Hist = zeros(nDofs, 30); % Pre-allocate
            obj.History_Time = zeros(30, 1);
        end
    end
    
    methods (Access = protected)
        % Core Newton-Raphson Loop
        [converged, U_out, reaction, iter] = newtonLoop(obj, F_ext, U_start, fixed_dofs)
        
        % Utility for history committing
        function updateHistory(obj, time, U_sol)
            obj.StepCount = obj.StepCount + 1;
            if obj.StepCount > size(obj.U_Hist, 2)
                obj.U_Hist(:, end+20) = 0; % Grow
                obj.History_Time(end+20) = 0;
            end
            obj.History_Time(obj.StepCount) = time;
            obj.U_Hist(:, obj.StepCount) = U_sol;
            obj.U = U_sol;
        end
    end
end
