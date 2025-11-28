classdef FEM_Solver_ArcLength < FEM_Solver
    % Inherits from your previous FEM_Solver
    
    properties
        LambdaHist  % History of Load Factors
        U_Hist      % History of Displacements (for plotting)
    end
    
    methods
        function obj = FEM_Solver_ArcLength(preObj)
            obj@FEM_Solver(preObj);
            obj.LambdaHist = [];
            obj.U_Hist = [];
        end
    end
    methods
        solveArcLength(obj, arcRadius, maxSteps, maxIter, tol)
    end        
end

% % Helper to map free dofs back to full
% function v = d_du_free_full(n, val, idx)
%     v = zeros(n,1);
%     v(idx) = val;
% end