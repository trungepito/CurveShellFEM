function plotPlasticYield(obj, stepIdx)
% PLOTPLASTICYIELD  Visualise the through-thickness plastic yield front.
%
% For each element the fraction of through-thickness layers that have
% yielded (p > 0) is computed at each of the 4 in-plane Gauss points and
% averaged to give a single element indicator:
%
%   0.0  = fully elastic
%   0.2  = first layer yielded (surface)
%   0.6  = three layers yielded
%   1.0  = fully yielded through thickness
%
% The result is plotted as an element-constant contour (no SPR, since
% yield-depth is a discrete indicator, not a smooth field).
%
% Input:
%   stepIdx  column of U_Hist; defaults to current step

if nargin < 2 || isempty(stepIdx)
    stepIdx = obj.Solver.StepCount;
end

% ── GP recovery ──────────────────────────────────────────────────
gpCell = obj.recoverAllGaussPoints(stepIdx);

Nodes    = obj.Model.Mesh.Nodes;
Elements = double(obj.Model.Mesh.Elements);
nElems   = size(Elements, 1);

% ── Compute per-element average yield depth ──────────────────────
elemYield = zeros(nElems, 1);

for e = 1:nElems
    gp = gpCell{e};
    % Average over 4 in-plane GPs; for each in-plane GP: 5 layers
    total_yield = 0;
    for iGP = 1:4
        block = (iGP-1)*5 + (1:5);
        total_yield = total_yield + sum([gp(block).yielded]);
    end
    elemYield(e) = total_yield / 20;   % fraction of 20 GP points
end

% ── Plot (element-constant, face colour) ─────────────────────────
figure;

% Map element scalar to nodal for patch rendering (constant per face)
faceConn = double(Elements(:, 1:4));

U  = obj.getDisplacementAtStep(stepIdx);
dx = U(1:6:end);  dy = U(2:6:end);  dz = U(3:6:end);
bb_diag  = norm(max(Nodes) - min(Nodes));
disp_max = max(sqrt(dx.^2 + dy.^2 + dz.^2));
scale    = 0;
if disp_max > 1e-12
    scale = 0.05 * bb_diag / disp_max;
end
plotNodes = Nodes + scale * [dx, dy, dz];

% Face colour from element scalar (FaceVertexCData with FaceColor='flat')
patch('Faces', faceConn, ...
      'Vertices', plotNodes, ...
      'FaceVertexCData', elemYield, ...
      'FaceColor', 'flat', ...
      'EdgeColor', [0.4 0.4 0.4], ...
      'LineWidth', 0.3);

colormap(hot);
clim([0 1]);
cb = colorbar;
cb.Label.String = 'Through-thickness yield fraction (0=elastic, 1=fully plastic)';
cb.Ticks = [0, 0.2, 0.4, 0.6, 0.8, 1.0];

xlabel('X');  ylabel('Y');  zlabel('Z');
axis equal;  grid on;  view(3);
title(sprintf('Plastic yield front — step %d  (disp ×%.1f)', stepIdx, scale));
drawnow;
end
