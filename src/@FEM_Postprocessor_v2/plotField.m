function plotField(obj, fieldName, stepIdx, opts)
% PLOTFIELD  Render a nodal field as a coloured 3D shell contour.
%
% Syntax:
%   Post.plotField('von_mises')
%   Post.plotField('von_mises', stepIdx)
%   Post.plotField('von_mises', stepIdx, struct('deformed',true,'scale',10))
%
% Options struct fields (all optional):
%   deformed    logical  — overlay deformed shape (default: true)
%   scale       scalar   — displacement magnification factor (default: auto)
%   colormap    string   — MATLAB colormap name (default: 'turbo')
%   title       string   — figure title override
%   newfig      logical  — open a new figure (default: true)

if nargin < 3 || isempty(stepIdx), stepIdx = obj.Solver.StepCount; end
if nargin < 4, opts = struct(); end

if ~isfield(opts, 'deformed'),  opts.deformed = true;  end
if ~isfield(opts, 'colormap'),  opts.colormap = 'turbo'; end
if ~isfield(opts, 'newfig'),    opts.newfig   = true;   end

% ── Recover field ────────────────────────────────────────────────
field = obj.recoverField(fieldName, stepIdx);

% ── Node positions ───────────────────────────────────────────────
Nodes    = obj.Model.Mesh.Nodes;
Elements = double(obj.Model.Mesh.Elements);

if opts.deformed
    U = obj.getDisplacementAtStep(stepIdx);
    dx = U(1:6:end);  dy = U(2:6:end);  dz = U(3:6:end);

    % Auto-scale: target 5% of bounding-box diagonal
    if ~isfield(opts, 'scale')
        bb_diag  = norm(max(Nodes) - min(Nodes));
        disp_max = max(sqrt(dx.^2 + dy.^2 + dz.^2));
        if disp_max > 1e-12
            opts.scale = 0.05 * bb_diag / disp_max;
        else
            opts.scale = 1;
        end
    end

    plotNodes = Nodes + opts.scale * [dx, dy, dz];
else
    plotNodes = Nodes;
end

% ── Plot ─────────────────────────────────────────────────────────
if opts.newfig, figure; end

% Use only corner nodes (1:4) for patch faces — midside nodes handled
% by MATLAB patch as interior (ignored for flat faces, fine for viz).
nElems  = size(Elements, 1);
nNodes  = size(Nodes, 1);
faceConn = double(Elements(:, 1:4));   % [nElems x 4] corner connectivity

patch('Faces', faceConn, ...
      'Vertices', plotNodes, ...
      'FaceVertexCData', field, ...
      'FaceColor', 'interp', ...
      'EdgeColor', 'none');

colormap(opts.colormap);
cb = colorbar;
cb.Label.String = fieldName;

xlabel('X');  ylabel('Y');  zlabel('Z');
axis equal;  grid on;  view(3);

if isfield(opts, 'title')
    title(opts.title);
else
    if opts.deformed
        title(sprintf('%s — step %d  (disp ×%.1f)', fieldName, stepIdx, opts.scale));
    else
        title(sprintf('%s — step %d  (undeformed)', fieldName, stepIdx));
    end
end

% Draw undeformed mesh outline in thin gray
if opts.deformed
    patch('Faces', faceConn, ...
          'Vertices', Nodes, ...
          'FaceColor', 'none', ...
          'EdgeColor', [0.7 0.7 0.7], ...
          'LineWidth', 0.3, ...
          'FaceAlpha', 0);
end

drawnow;
end
