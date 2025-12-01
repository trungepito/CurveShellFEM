function renderPlot(obj, values,fieldType,layer,scale)
titleStr=[fieldType '-' layer];
figure;
nodes = obj.Model.Mesh.Nodes;
elems = obj.Model.Mesh.Elements;

def_nodes = nodes;
switch fieldType
    case 'Buckling'
        for i=1:size(nodes,1)
            U=obj.Solver.ModeShapes(:,1);
            max_u=max(abs(U));
            model_dim = max(max(nodes)) - min(min(nodes));
            if max_u>0,scale=1*model_dim/max_u;end
            def_nodes(i,:) = nodes(i,:) + U((i-1)*6+1:(i-1)*6+3)' * scale;
        end
    otherwise
        if ~isempty(obj.Solver.U)
            % Calculate scale to make deformation visible but not crazy
            max_u = max(abs(obj.Solver.U));
            model_dim = max(max(nodes)) - min(min(nodes));
            if max_u > 0, scale = 0.1 * model_dim / max_u; end
        end
        for i=1:size(nodes,1)
            def_nodes(i,:) = nodes(i,:) + obj.Solver.U((i-1)*6+1:(i-1)*6+3)' * scale;
        end
end
% Deform Mesh
% scale = 1.5; % Set to 1.0 for true deform, 0 for undeformed

% Patch Plot with Interpolated Colors
patch('Vertices', def_nodes, 'Faces', elems(:, [1,2,3,4]), ...
    'FaceVertexCData', values, ...
    'FaceColor', 'interp', ... % 'interp' turns on smoothing
    'EdgeColor', 'k', 'EdgeAlpha', 0.2);
% patch('Vertices', def_nodes, 'Faces', elems(:, [1,2,3,4]), ...
%     'FaceVertexCData', values, ...
%     'FaceColor', 'interp', ... % 'interp' turns on smoothing
%     'EdgeColor', 'none'); % Set EdgeColor to 'none' to hide edges

axis equal; grid on; colormap jet; colorbar;
title(titleStr);
view(3);
end