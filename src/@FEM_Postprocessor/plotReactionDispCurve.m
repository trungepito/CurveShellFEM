function plotReactionDispCurve(obj, controlNodeID, controlDOF)
% Plots the Reaction Force vs Prescribed Displacement

if isempty(obj.Solver.ReactionHist)
    error('No displacement control history found.');
end

% X-Axis: Displacement at the control node
% We can extract this from U_Hist
global_dof = (controlNodeID-1)*6 + controlDOF;
disp_data = obj.Solver.U_Hist(global_dof, :);

% Y-Axis: Reaction Force recorded by solver
load_data = obj.Solver.ReactionHist;

figure('Name', 'Reaction-Displacement Curve', 'Color', 'w');
plot(disp_data, load_data, 'r-o', 'LineWidth', 2, 'MarkerSize', 4);
grid on;
xlabel(sprintf('Prescribed Displacement U(%d) [m]', controlDOF));
ylabel(sprintf('Reaction Force F(%d) [N]', controlDOF));
title('Equilibrium Path (Displacement Control)');

% Annotate Peak Load (Limit Point)
[maxLoad, idx] = max(abs(load_data));
hold on;
plot(disp_data(idx), maxLoad, 'k*', 'MarkerSize', 10);
text(disp_data(idx), maxLoad, sprintf('  Peak: %.2f N', maxLoad), ...
    'VerticalAlignment', 'bottom');
end