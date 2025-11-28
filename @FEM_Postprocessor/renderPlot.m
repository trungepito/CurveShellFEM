function renderPlot(obj, values, titleStr)
            figure;
            nodes = obj.Model.Mesh.Nodes;
            elems = obj.Model.Mesh.Elements;

            % Deform Mesh
            scale = 0; % Set to 1.0 for true deform, 0 for undeformed
            if ~isempty(obj.Solver.U)
                % Calculate scale to make deformation visible but not crazy
                max_u = max(abs(obj.Solver.U));
                model_dim = max(max(nodes)) - min(min(nodes));
                if max_u > 0, scale = 0.1 * model_dim / max_u; end
            end

            def_nodes = nodes;
            for i=1:size(nodes,1)
                def_nodes(i,:) = nodes(i,:) + obj.Solver.U((i-1)*5+1:(i-1)*5+3)' * scale;
            end

            % Patch Plot with Interpolated Colors
            patch('Vertices', def_nodes, 'Faces', elems(:, [1,2,3,4]), ...
                'FaceVertexCData', values, ...
                'FaceColor', 'interp', ... % 'interp' turns on smoothing
                'EdgeColor', 'k', 'EdgeAlpha', 0.2);

            axis equal; grid on; colormap jet; colorbar;
            title(titleStr);
            view(3);
        end