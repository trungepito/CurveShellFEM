function assembleK(obj)
% ASSEMBLEK - Assembles the Global Stiffness Matrix (Sparse).
%
% v3.1: Delegates to Assembler.elastic (stateless static method).
% See also: Assembler, FEM_Solver, buildElementCache
fprintf('Assembling Global Stiffness Matrix...\n');
tick = tic;

nTotalDofs = size(obj.Model.Mesh.Nodes, 1) * 6;

% Delegate to stateless Assembler (I1)
obj.GlobalK = Assembler.elastic(obj.Elements, obj.SctrMap, nTotalDofs);

t_elapsed = toc(tick);
fprintf('Assembly Done. DOFs: %d. Time: %.4f s\n', nTotalDofs, t_elapsed);
end