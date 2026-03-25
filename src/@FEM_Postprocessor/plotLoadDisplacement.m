function plotLoadDisplacement(obj, nodeID, dofID)
% Plots the Load vs Displacement curve for a specific Node/DOF

if isempty(obj.Solver.U_Hist)
    error('No history data found. Run solveNonLinear first.');
end

% Extract Data
lambdas = obj.Solver.LambdaHist;
% Calculate actual Load Magnitude (assuming proportional loading)
% We look at the load applied to THIS node to scale, or Total Load?
% Usually Y-axis is "Load Factor" or "Total Applied Force".
% Let's use Load Factor (Lambda).

global_dof = (nodeID-1)*6 + dofID;
disps = obj.Solver.U_Hist(global_dof, :);

figure('Name', 'Load-Displacement Curve', 'Color', 'w');
plot(disps, lambdas, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
grid on;
xlabel(sprintf('Displacement at Node %d, DOF %d (m)', nodeID, dofID));
ylabel('Load Factor (\lambda)');
title('Nonlinear Equilibrium Path');

% Add Energy plot
if ~isempty(obj.Solver.StrainEnergy)
    yyaxis right
    plot(disps, obj.Solver.StrainEnergy, 'r--');
    ylabel('External Work (J)');
    legend('Load Factor', 'Work');
end
end