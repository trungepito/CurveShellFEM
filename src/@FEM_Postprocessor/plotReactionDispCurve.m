function plotReactionDispCurve(obj, controlNodeID, controlDOF)
% Plots the Reaction Force vs Prescribed Displacement

% Check if we have reaction data (Disp Control) or Load Factor data (Arc Length)
hasReaction = isprop(obj.Solver, 'ReactionHist') && ~isempty(obj.Solver.ReactionHist);
hasLambda = isprop(obj.Solver, 'LambdaHist') && ~isempty(obj.Solver.LambdaHist);

if ~hasReaction && ~hasLambda
    error('No load or reaction history found in solver.');
end

% X-Axis: Displacement at the control node
global_dof = (controlNodeID-1)*6 + controlDOF;
disp_data = obj.Solver.U_Hist(global_dof, :);
disp_data = disp_data(:); % Enforce column

% Y-Axis: Load/Reaction
if hasLambda
    load_data = obj.Solver.LambdaHist;
    load_data = load_data(:);
    ylabel_str = 'Load Factor (\lambda)';
elseif hasReaction
    load_data = obj.Solver.ReactionHist;
    if iscell(load_data), load_data = load_data{1}; end
    % Note: If multiple DOFs are fixed, this might need refinement.
    % For now, we take the first row if it's a matrix.
    if size(load_data, 1) > 1, load_data = load_data(1, :); end
    load_data = load_data(:); 
    ylabel_str = sprintf('Reaction Force F(%d) [N]', controlDOF);
else
    error('No load or reaction history found.');
end

% Ensure size consistency (trim to shortest if needed)
nPts = min(length(disp_data), length(load_data));
disp_data = disp_data(1:nPts);
load_data = load_data(1:nPts);

figure('Name', 'Equilibrium Path', 'Color', 'w');
plot(disp_data, load_data, 'b-o', 'LineWidth', 2, 'MarkerSize', 4);
grid on;
xlabel(sprintf('Displacement U(%d) [m]', controlDOF));
ylabel(ylabel_str);
title('Equilibrium Path (GMNIA)');

% Annotate Peak Load (Limit Point)
[maxLoad, idx] = max(abs(load_data));
hold on;
plot(disp_data(idx), maxLoad, 'k*', 'MarkerSize', 10);
text(disp_data(idx), maxLoad, sprintf('  Peak: %.2f N', maxLoad), ...
    'VerticalAlignment', 'bottom');
end