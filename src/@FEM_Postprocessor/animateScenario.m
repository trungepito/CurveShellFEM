
function animateScenario(obj, plotNodeID, plotDOF, scaleFactor, speed)
% animateScenario(plotNodeID, plotDOF, scaleFactor, speed)
%
% Inputs:
%   plotNodeID: Node ID to plot on the Load/Disp curve (X-Axis)
%   plotDOF:    DOF (1=X, 2=Y, 3=Z) for that node
%   scaleFactor: (Optional) Exaggeration factor for deformation. Default = 1.0
%   speed:      (Optional) Delay between frames in seconds. Default = 0.1

if nargin < 4, scaleFactor = 1.0; end
if nargin < 5, speed = 0.1; end

% 1. Check Data Availability
if isempty(obj.Solver.U_Hist)
    error('No analysis history found. Run a non-linear solver first.');
end

nSteps = size(obj.Solver.U_Hist, 2);
nodes0 = obj.Model.Mesh.Nodes;
elements = obj.Model.Mesh.Elements;

% 2. Prepare Curve Data
% Determine if Load Control (Lambda) or Displacement Control (Reaction)
isDispControl = ~isempty(obj.Solver.ReactionHist);

% X-Axis Data: Displacement of the chosen node
dofIndex = (plotNodeID-1)*6 + plotDOF;
x_data_full = obj.Solver.U_Hist(dofIndex, :);

% Y-Axis Data: Load Factor or Reaction Force
if isDispControl
    y_data_full = obj.Solver.ReactionHist;
    y_label_str = sprintf('Reaction Force F_%d [N]', plotDOF);
    title_str = 'Equilibrium Path (Disp. Control)';
else
    % Assuming proportional loading, Y is Lambda
    y_data_full = obj.Solver.LambdaHist;
    y_label_str = 'Load Factor \lambda';
    title_str = 'Equilibrium Path (Load Control)';
end

% 3. Calculate Global Limits for Stable Camera
% We scan the history to find the maximum bounding box of the deformed mesh.
% This prevents the "zooming in/out" effect during animation.
fprintf('Preprocessing animation limits...\n');
% max_abs_disp = max(abs(obj.Solver.U_Hist(:)));
max_abs_dispU = max(abs(obj.Solver.U_Hist(1:6:end,:)),[],"all");
max_abs_dispV = max(abs(obj.Solver.U_Hist(2:6:end,:)),[],"all");
max_abs_dispW = max(abs(obj.Solver.U_Hist(3:6:end,:)),[],"all");

min_x = min(nodes0(:,1)) - max_abs_dispU*scaleFactor;
max_x = max(nodes0(:,1)) + max_abs_dispU*scaleFactor;
min_y = min(nodes0(:,2)) - max_abs_dispV*scaleFactor;
max_y = max(nodes0(:,2)) + max_abs_dispV*scaleFactor;
min_z = min(nodes0(:,3)) - max_abs_dispW*scaleFactor;
max_z = max(nodes0(:,3)) + max_abs_dispW*scaleFactor;

% 4. Initialize Visualization
fig = figure('Name', 'Nonlinear Simulation', 'Color', 'w', 'Position', [100, 100, 1200, 600]);

% --- Subplot 1: 3D View ---
ax3D = subplot(1, 2, 1);
axis(ax3D, 'equal');
grid(ax3D, 'on');
view(ax3D, 3);
xlabel(ax3D, 'X'); ylabel(ax3D, 'Y'); zlabel(ax3D, 'Z');
title(ax3D, 'Deformation (Displacement Mag.)');
xlim(ax3D, [min_x max_x]);
ylim(ax3D, [min_y max_y]);
zlim(ax3D, [min_z max_z]);

% Create initial Patch object
% Color data will be Displacement Magnitude initially
p = patch(ax3D, 'Vertices', nodes0, 'Faces', elements(:, 1:4), ...
    'FaceVertexCData', zeros(size(nodes0,1),1), ...
    'FaceColor', 'interp', 'EdgeColor', 'k', 'FaceAlpha', 0.9);
colormap(ax3D, 'jet');
cbar = colorbar(ax3D);
cbar.Label.String = 'Disp Magnitude [m]';
clim(ax3D, [0, sqrt(max_abs_dispW^2+max_abs_dispV^2+max_abs_dispU^2)*scaleFactor]); % Fix color scale

% --- Subplot 2: 2D Curve ---
ax2D = subplot(1, 2, 2);
hold(ax2D, 'on'); grid(ax2D, 'on'); box(ax2D, 'on');
xlabel(ax2D, sprintf('Displacement U_%d at Node %d [m]', plotDOF, plotNodeID));
ylabel(ax2D, y_label_str);
title(ax2D, title_str);

% Set fixed limits for the curve too, so it doesn't rescale
xlim(ax2D, [min(x_data_full) max(x_data_full)] * 1.1);
ylim(ax2D, [min(y_data_full) max(y_data_full)] * 1.1);

% Initialize curve objects
curve_line = plot(ax2D, x_data_full(1), y_data_full(1), 'b-', 'LineWidth', 2);
current_pt = plot(ax2D, x_data_full(1), y_data_full(1), 'r*', 'MarkerSize', 10, 'LineWidth', 2);

% 5. Animation Loop
fprintf('Starting Animation...\n');
for step = 1:nSteps

    if ~isvalid(fig), break; end % Handle closed figure

    % --- A. Update Mesh ---
    U_step = obj.Solver.U_Hist(:, step);

    % Calculate Deformed Vertices
    def_nodes = zeros(size(nodes0));
    % disp_mag = zeros(size(nodes0,1), 1);

    % Vectorized update for speed
    % (Reshape U into [N x 6], take first 3 columns, scale, add to nodes)
    % Assuming U is ordered: Node1_u, Node1_v, ...
    % Faster than looping:
    u_x = U_step(1:6:end);
    u_y = U_step(2:6:end);
    u_z = U_step(3:6:end);

    def_nodes(:,1) = nodes0(:,1) + u_x * scaleFactor;
    def_nodes(:,2) = nodes0(:,2) + u_y * scaleFactor;
    def_nodes(:,3) = nodes0(:,3) + u_z * scaleFactor;

    disp_mag = sqrt(u_x.^2 + u_y.^2 + u_z.^2);

    % Update Patch Data
    set(p, 'Vertices', def_nodes, 'FaceVertexCData', disp_mag);

    % --- B. Update Curve ---
    % Update the line to include data up to current step
    set(curve_line, 'XData', x_data_full(1:step), 'YData', y_data_full(1:step));

    % Move the red marker to current tip
    set(current_pt, 'XData', x_data_full(step), 'YData', y_data_full(step));

    % --- C. Titles and Timing ---
    title(ax3D, sprintf('Step %d/%d (Scale: %.1fx)', step, nSteps, scaleFactor));

    drawnow;
    pause(speed);
end
fprintf('Animation Complete.\n');
end
