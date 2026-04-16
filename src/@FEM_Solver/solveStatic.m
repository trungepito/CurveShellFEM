function solveStatic(obj)
% solveStatic: Reduced System Linear Solver (v3.0)

fprintf('[Solver] Starting Linear Static Solution...\n');

% 1. Assembly
obj.assembleK();
obj.applyLoads();
obj.applyConstraints();

% 2. Extract Reduced System
f = obj.FreeDofs;
K_red = obj.GlobalK(f, f);
F_red = obj.GlobalF(f);

% 3. Solve
fprintf('[Solver] Solving Reduced System (%d DOFs)...\n', length(f));
if isempty(f)
    error('No free degrees of freedom. Check boundary conditions.');
end

u_red = K_red \ F_red;

% 4. Map back to Global U
nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
obj.U = zeros(nDofs, 1);
obj.U(f) = u_red;

% Shout it out the solution event!
evtData=SolverLinearEventData(obj.U);
notify(obj, 'Lin_sol', evtData);

fprintf('[Solver] Static Solution Complete.\n');

end