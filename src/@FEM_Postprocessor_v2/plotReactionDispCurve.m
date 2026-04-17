function plotReactionDispCurve(obj, reactionHist, dispNodeID, dispDOF, stageIdx)
% PLOTREACTIONDISPCURVE  Load-displacement or reaction-displacement curve.
%
% Works with any solver that populates obj.state.StepCount and obj.state.U_Hist.
%
% Syntax:
%   % Adaptive solver — pass summed reaction history for stage s:
%   Post.plotReactionDispCurve(Sol.ReactionHist{s}, nodeID, dofIdx, s)
%
%   % Nonlinear solver — pass [] for reactionHist to use LambdaHist:
%   Post.plotReactionDispCurve([], nodeID, dofIdx, 1)
%
% Input:
%   reactionHist  [nFixedDOF × nSteps] matrix, or [] to use LambdaHist
%   dispNodeID    node to track (1-based)
%   dispDOF       local DOF index (1=Ux, 2=Uy, 3=Uz)
%   stageIdx      optional integer for title label

if nargin < 5, stageIdx = []; end

nSteps = obj.Snapshot.StepCount;
if nSteps < 1
    warning('FEM_Postprocessor_v2:noHistory', 'No history to plot.');
    return;
end

% ── Extract displacement history at the tracked DOF ──────────────
dispDOF_global = (dispNodeID - 1)*6 + dispDOF;
disp_hist = obj.Snapshot.U_Hist(dispDOF_global, :);

% ── Determine load measure ────────────────────────────────────────
if ~isempty(obj.Snapshot.LambdaHist) && any(obj.Snapshot.LambdaHist ~= 0)
    load_hist = obj.Snapshot.LambdaHist;
    yLabel    = 'Load factor \lambda';
elseif ~isempty(obj.Snapshot.ReactionHist) && ~isempty(stageIdx) && ...
       stageIdx <= length(obj.Snapshot.ReactionHist) && ...
       ~isempty(obj.Snapshot.ReactionHist{stageIdx})
       
    % Sum all reaction DOFs for this stage to get total reaction force
    % obj.Snapshot.ReactionHist{s} is a struct with .values [nFixed x nSteps]
    load_hist = sum(obj.Snapshot.ReactionHist{stageIdx}.values, 1);
    yLabel    = 'Reaction force (sum)';
else
    load_hist = 1:nSteps;
    yLabel    = 'Step index';
end

% ── Align lengths ─────────────────────────────────────────────────
nPts  = min(length(disp_hist), length(load_hist));
d_plt = disp_hist(1:nPts);
l_plt = load_hist(1:nPts);

% ── Plot ──────────────────────────────────────────────────────────
figure;
plot(d_plt, l_plt, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4, ...
    'MarkerFaceColor', [0.2 0.4 0.8]);

xlabel(sprintf('Node %d  DOF %d  displacement', dispNodeID, dispDOF), ...
    'FontSize', 11);
ylabel(yLabel, 'FontSize', 11);

if ~isempty(stageIdx)
    title(sprintf('Load–displacement curve — stage %d', stageIdx), ...
        'FontSize', 12);
else
    title('Load–displacement curve', 'FontSize', 12);
end
grid on;

% Mark limit points (local maxima of load factor)
if nPts > 4
    % [~, locs] = findpeaks(l_plt);
    locs=find(l_plt==max(l_plt));
    if ~isempty(locs)
        hold on;
        plot(d_plt(locs), l_plt(locs), 'rv', ...
            'MarkerSize', 8, 'MarkerFaceColor', 'r');
        legend('Path', 'Limit points', 'Location', 'best');
    end
end

drawnow;
end
