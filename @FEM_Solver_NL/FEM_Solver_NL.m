classdef FEM_Solver_NL < FEM_Solver
    % Inherits from your previous FEM_Solver
    
    properties
        LambdaHist      % History of Load Factors
        U_Hist          % History of Displacements (for plotting)
        ReactionHist    % Reaction Forces (if needed)
        StrainEnergy    % History of work done
    end
    
    methods
        function obj = FEM_Solver_NL(preObj)
            obj@FEM_Solver(preObj);
            obj.LambdaHist = [];
            obj.U_Hist = [];
        end
    end
    methods
        solveNonLinear(obj, SolNLopt)
        solveDisplacementControl(obj, controlNodeID, controlDOF, targetDisp, nSteps, maxIter, tol)
    end        
    methods(Access=private)
        [KT, F_int] = assembleTangentSystem(obj)
        F_int = assembleinternalforceONLY(obj,U_trial)
        linesearch(obj,U_old,dU,R,F_ext_current,free_dofs)
    end
end

% % Helper to map free dofs back to full
% function v = d_du_free_full(n, val, idx)
%     v = zeros(n,1);
%     v(idx) = val;
% end