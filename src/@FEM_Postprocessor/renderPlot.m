function renderPlot(obj, values, fieldType, opts)
% RENDERPLOT Internal helper to generate 3D plots
% values: Nodal values to plot
% fieldType: 'Displacement', 'VonMises', etc.
% opts: Struct with .layer, .scale, .Nummode, etc.

if nargin < 4 || isempty(opts)
    opts = struct('layer', 'Mid', 'scale', 1.0);
end

nodes = obj.Model.Mesh.Nodes;
elems = obj.Model.Mesh.Elements;
layer = opts.layer;
scale = opts.scale;
titleStr = sprintf('%s at %s layer', fieldType, layer);

% 1. Determine Displacement Vector
U_disp = [];
if strcmp(fieldType, 'Buckling')
    if isfield(opts, 'Nummode') && ~isempty(obj.Solver.ModeShapes)
        U_disp = obj.Solver.ModeShapes(:, opts.Nummode);
        U_disp = U_disp / norm(U_disp);
        % Auto-scale buckling modes to 10% of model size
        model_dim = max(max(nodes)) - min(min(nodes));
        scale = scale * model_dim * 0.1;
    end
else
    U_disp = obj.Solver.U;
    % Auto-scale for visibility if displacements are tiny
    if ~isempty(U_disp) 
        max_u = max(abs(U_disp));
        if max_u > 0 && max_u < 1e-6
            model_dim = max(max(nodes)) - min(min(nodes));
            scale = scale * model_dim * 0.1 / max_u;
        end
    end
end

% 2. Deform Mesh (Vectorized)
def_nodes = nodes;
if ~isempty(U_disp)
    u_x = U_disp(1:6:end);
    u_y = U_disp(2:6:end);
    u_z = U_disp(3:6:end);
    def_nodes(:,1) = nodes(:,1) + u_x * scale;
    def_nodes(:,2) = nodes(:,2) + u_y * scale;
    def_nodes(:,3) = nodes(:,3) + u_z * scale;
end

% 3. Visualization
if ~ishold, figure('Color', 'w'); end

% Plot 8-node serendipity elements as patches (using corner nodes 1-4 for visualization)
p = patch('Vertices', def_nodes, 'Faces', elems(:, 1:4), ...
    'FaceVertexCData', values, ...
    'FaceColor', 'interp', ...
    'EdgeColor', 'k', 'EdgeAlpha', 0.1);

axis equal; 
grid on; 
colormap jet; 
cb = colorbar; 
cb.Label.String = fieldType;
box on;
title(titleStr, 'FontSize', 12);
view(3);
camlight('headlight'); 
lighting gouraud;
end