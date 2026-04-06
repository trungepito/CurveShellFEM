function plotReactionDispCurve(obj, reactionHist, dispNodeID, dispDOF, stageIdx)
% PLOTREACTIONDISPCURVE  Load-displacement or reaction-displacement curve.
%
% Works with both FEM_Solver_Adaptive (ReactionHist cell) and
% FEM_Solver_ArcLength (LambdaHist + U_Hist) outputs.
%
% Syntax:
%   % Adaptive solver — pass summed reaction history for stage s:
%   Post.plotReactionDispCurve(Sol.ReactionHist{s}, nodeID, dofIdx, s)
%
%   % Arc-length solver — pass [] for reactionHist to use LambdaHist:
%   Post.plotReactionDispCurve([], nodeID, dofIdx, 1)
%
% Input:
%   reactionHist  [nFixedDOF × nSteps] matrix, or [] to use LambdaHist
%   dispNodeID    node to track (1-based)
%   dispDOF       local DOF index (1=Ux, 2=Uy, 3=Uz)
%   stageIdx      optional integer for title label

if nargin < 5, stageIdx = []; end

nSteps = obj.Solver.StepCount;
if nSteps < 1
    warning('FEM_Postprocessor:noHistory', 'No history to plot.');
    return;
end

% ── Extract displacement history at the tracked DOF ──────────────
dispDOF_global = (dispNodeID - 1)*6 + dispDOF;
if size(obj.Solver.U_Hist, 2) < nSteps
    nSteps = size(obj.Solver.U_Hist, 2);
end
disp_hist = obj.Solver.U_Hist(dispDOF_global, 1:nSteps);

% ── Determine load measure ────────────────────────────────────────
useArcLength = isprop(obj.Solver, 'LambdaHist') && ...
               ~isempty(obj.Solver.LambdaHist);

if useArcLength
    load_hist = obj.Solver.LambdaHist(:)';
    load_hist = load_hist(1:min(nSteps, end));
    yLabel    = 'Load factor \lambda';
elseif isnumeric(reactionHist{stageIdx}) && ~isempty(reactionHist)
    % Sum all reaction DOFs to get total reaction force
    load_hist = sum(reactionHist{stageIdx}, 1);
    load_hist = load_hist(1:min(nSteps, end));
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
