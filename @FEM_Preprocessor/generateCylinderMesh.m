function generateCylinderMesh(obj, R, L, Nu, Nv)
% Generates nodes and elements for a cylinder panel (corrected for 8-node element)
fprintf('[Preprocessor] Generating Mesh...\n');

nodes = [];
% We still use a (2*Nu+1) x (2*Nv+1) template for mapping,
% but only populate used nodes.
node_map = zeros(2*Nu+1, 2*Nv+1);

theta = linspace(0, pi/2, 2*Nu+1);
z_vals = linspace(0, L, 2*Nv+1);

cnt = 0;
% Population Loop: Only populate nodes that are corners or mid-sides
for j = 1:length(z_vals) % Fine grid column (v direction)
    for i = 1:length(theta) % Fine grid row (u direction)
        cnt = cnt + 1;
        node_map(i, j) = cnt;
        % Check if the node index (i, j) corresponds to an unused center
        is_center_u = (mod(i, 2) == 0) && (i > 1) && (i < length(theta));
        is_center_v = (mod(j, 2) == 0) && (j > 1) && (j < length(z_vals));

        % Skip node if it is the center of a 2x2 patch
        if is_center_u && is_center_v
            % This node (r+1, c+1) is only required for a 9-node element, not 8-node.
            cnt=cnt-1;
            continue;
        end
        % If the node is corner or mid-side, we store it.
        nodes(cnt, :) = [R*cos(theta(i)), R*sin(theta(i)), z_vals(j)];
    end
end

elems = [];
% Element definition loop remains the same, but now it uses the node_map
% indices which correspond to the correct, non-skipped nodes.
for v = 1:Nv
    for u = 1:Nu
        r = 2*u-1; c = 2*v-1;

        % Corner nodes (n1-n4)
        n1=node_map(r,c); n2=node_map(r+2,c); n3=node_map(r+2,c+2); n4=node_map(r,c+2);
        % Mid-side nodes (n5-n8)
        n5=node_map(r+1,c); n6=node_map(r+2,c+1); n7=node_map(r+1,c+2); n8=node_map(r,c+1);

        % The map check should ensure no zero IDs are generated, but it's good practice
        if any([n1, n2, n3, n4, n5, n6, n7, n8] == 0)
            error('Mesh generation error: A node ID was zero.');
        end

        elems = [elems; n1, n2, n3, n4, n5, n6, n7, n8];
    end
end

obj.Mesh.Nodes = nodes;
obj.Mesh.Elements = elems;
obj.computeNormals();
end