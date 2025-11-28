function solveStatic(obj)
fprintf('[Solver] Assembling Stiffness Matrix...\n');
obj.assembleK();
fprintf('[Solver] Applying Loads and BCs...\n');
obj.applyLoads();
obj.applyConstraints();
% Apply Constraints (Identity/Penalty Method)
K_sys = obj.GlobalK;
F_sys = obj.GlobalF;

fprintf('[Solver] Solving Linear System...\n');
obj.U = K_sys \ F_sys;
fprintf('[Solver] Static Solution Complete.\n');
end