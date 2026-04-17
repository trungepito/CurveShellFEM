function animateHistory(obj, nodeID, dofIdx)
% ANIMATEHISTORY  Scrub through all converged steps and animate a field.
%
% Opens a figure with a slider-controlled animation of the displacement
% magnitude contour, updating at each step in Solver.U_Hist.
%
% Input:
%   nodeID   node to mark with a scatter point during animation ([] to skip)
%   dofIdx   DOF to track in title readout (1=Ux, 2=Uy, 3=Uz); default 3

if nargin < 2, nodeID = []; end
if nargin < 3, dofIdx = 3;  end

nSteps = obj.Snapshot.StepCount;
if nSteps < 1
    warning('FEM_Postprocessor_v2:noHistory', 'No solution history available.');
    return;
end

Nodes    = obj.Model.Mesh.Nodes;
Elements = double(obj.Model.Mesh.Elements);
faceConn = double(Elements(:, 1:4));
bb       = norm(max(Nodes) - min(Nodes));

% ── Pre-render frame 1 ────────────────────────────────────────────
fig = figure('Name', 'Solution history animation');
ax  = axes(fig);

[plotNodes1, sc1] = deformedNodes(obj, 1, Nodes, bb);
field1 = obj.recoverField('displacement_total', 1);

hp = patch(ax, 'Faces', faceConn, 'Vertices', plotNodes1, ...
    'FaceVertexCData', field1, 'FaceColor', 'interp', 'EdgeColor', 'none');
colormap(ax, 'turbo');
colorbar(ax);
axis(ax, 'equal');  grid(ax, 'on');  view(ax, 3);
xlabel(ax, 'X');  ylabel(ax, 'Y');  zlabel(ax, 'Z');
title(ax, sprintf('Step 1 / %d  |  disp ×%.1f', nSteps, sc1));

if ~isempty(nodeID)
    hold(ax, 'on');
    hm = scatter3(ax, plotNodes1(nodeID,1), plotNodes1(nodeID,2), ...
        plotNodes1(nodeID,3), 60, 'k', 'filled');
end

% ── Slider ────────────────────────────────────────────────────────
if nSteps > 1
    uicontrol(fig, 'Style', 'slider', ...
        'Min', 1, 'Max', nSteps, 'Value', 1, ...
        'SliderStep', [1/max(nSteps-1,1), 5/max(nSteps-1,1)], ...
        'Units', 'normalized', 'Position', [0.1 0.02 0.8 0.04], ...
        'Callback', @(s,~) updateFrame(round(s.Value)));
end

    function updateFrame(step)
        fld = obj.recoverField('displacement_total', step);
        [pN, sc] = deformedNodes(obj, step, Nodes, bb);
        hp.Vertices        = pN;
        hp.FaceVertexCData = fld;
        if ~isempty(nodeID) && exist('hm', 'var')
            hm.XData = pN(nodeID,1);
            hm.YData = pN(nodeID,2);
            hm.ZData = pN(nodeID,3);
        end
        title(ax, sprintf('Step %d / %d  |  disp ×%.1f', step, nSteps, sc));
        drawnow;
    end
end

% ── Local helper: compute deformed node positions ─────────────────
function [plotNodes, scale] = deformedNodes(obj, step, Nodes, bb)
U  = obj.getDisplacementAtStep(step);
dx = U(1:6:end);  dy = U(2:6:end);  dz = U(3:6:end);
disp_max = max(sqrt(dx.^2 + dy.^2 + dz.^2));
if disp_max > 1e-12
    scale = 0.05 * bb / disp_max;
else
    scale = 1;
end
plotNodes = Nodes + scale * [dx, dy, dz];
end

