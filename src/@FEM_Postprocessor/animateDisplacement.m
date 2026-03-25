
function animateDisplacement(obj, ScaleFactor,speed, SaveVideo, VideoName)
if nargin < 3, ScaleFactor = 1.0; end
if nargin < 4, SaveVideo = false; end
if nargin < 5, VideoName = 'Simulation_Output'; end

fprintf('--- Starting Animation ---\n');

% 1. Prepare Visualization
hFig = figure('Color', 'w', 'Name', 'Nonlinear History Animation');
axis equal; grid on; hold on;
view(3); colormap(jet(256));
xlabel('X'); ylabel('Y'); zlabel('Z');

% Setup Video Writer
if SaveVideo
    v = VideoWriter(VideoName, 'MPEG-4');
    v.FrameRate = 30;
    open(v);
end

% Create the Mesh Graphics Object (Patch)
% We initialize with undeformed coordinates
elements = obj.Model.Mesh.Elements;
Nodes = obj.Model.Mesh.Nodes;

% hPatch = patch('Faces', Faces, 'Vertices', Nodes, ...
%     'FaceColor', 'interp', ...
%     'EdgeColor', [0.2 0.2 0.2], ...
%     'FaceAlpha', 0.9);

% Create a ColorBar with a fixed range (optional, but better for animation)
hPatch = patch( 'Vertices', Nodes, 'Faces', elements(:, 1:4), ...
    'FaceVertexCData', zeros(size(Nodes,1),1), ...
    'FaceColor', 'interp', 'EdgeColor', 'k', 'FaceAlpha', 0.9);
% colormap(ax3D, 'jet');
cbar = colorbar();
cbar.Label.String = 'Disp Magnitude [m]';
% Optimization: Pre-calculate element connectivity for stress averaging
% (Doing this inside the loop kills FPS)
fprintf('... Pre-computing connectivity maps ...\n');

% Initialize Counters
global_step = 1;
TotalSteps = size(obj.Solver.U_Hist, 2);

% 2. ANIMATION LOOP (Stage-Aware)
% We loop through the ReactionHist cells because they define the "Stages"
NumStages = length(obj.Solver.ReactionHist);

for s = 1:NumStages

    StageReactions = obj.Solver.ReactionHist{s};
    nStepsInStage = size(StageReactions, 2);

    fprintf('Rendering Stage %d (%d steps)...\n', s, nStepsInStage);

    for k = 1:nStepsInStage

        % Safety Check: Ensure we don't exceed global history
        if global_step > TotalSteps, break; end

        % A. Extract Data
        % ------------------------------------------------
        % Displacement for this step (Monolithic History)
        U_current = obj.Solver.U_Hist(:,global_step);
        Time_current = obj.Solver.History_Time(global_step);

        % Reactions for this step (Segmented History)
        % R_current is a vector of F_int values for the Fixed DOFs
        R_current = StageReactions(k, :);

        % Calculate Total Reaction Force (Resultant) for display
        % (Useful to see Load vs Displacement)
        TotalRxnSum = sum(abs(R_current));

        % B. Update Geometry
        % ------------------------------------------------
        % Deform Nodes: X_def = X_0 + U * Scale
        U_reshaped = reshape(U_current, 6, [])'; % [N x 6]
        DeformedNodes = Nodes + U_reshaped(:, 1:3) * ScaleFactor;

        % hPatch.Vertices = DeformedNodes;
        disp_mag = sqrt(U_reshaped(:,1).^2 + U_reshaped(:,2).^2 + U_reshaped(:,3).^2)* ScaleFactor;
        % C. Update Color (Stress Field)
        % ------------------------------------------------
        % Calculating stress for every frame is the bottleneck.
        % To keep it fast, we use a helper method that computes ONE field.

        % [NodeStress, ~] = obj.computeStressField(U_current);
        % hPatch.CData = disp_mag;
        set(hPatch, 'Vertices', DeformedNodes, 'FaceVertexCData', disp_mag);
        % D. Update Title & Info
        % ------------------------------------------------
        title_str = sprintf('Stage: %d | Time: %.3f s\nStep: %d (Global %d)\nReaction Norm: %.2e N', ...
            s, Time_current, k, global_step, TotalRxnSum);
        title(title_str, 'Interpreter', 'none');

        % E. Draw & Save
        % ------------------------------------------------
        % Use limitrate to prevent MATLAB from choking on the draw queue
        % drawnow limitrate;
        drawnow;
        pause(speed);
        if SaveVideo
            frame = getframe(hFig);
            writeVideo(v, frame);
        end

        global_step = global_step + 1;
    end
end

if SaveVideo
    close(v);
    fprintf('Video saved to %s.mp4\n', VideoName);
end
fprintf('--- Animation Complete ---\n');
end
