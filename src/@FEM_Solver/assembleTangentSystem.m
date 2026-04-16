function [KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)
% ASSEMBLETANGENTSYSTEM Unified assembly of Global KT, F_int, and Trial History
%
% v3.1: Delegates to Assembler.tangent (stateless static method).
% Enforces Trial-Commit pattern by returning TrialHist without mutating state.

if nargin < 2
    U_curr = obj.U;
end

nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;

% Delegate to stateless Assembler (I1)
[KT, F_int, TrialHist] = Assembler.tangent(U_curr, obj.Elements, obj.SctrMap, nDofs);
end
