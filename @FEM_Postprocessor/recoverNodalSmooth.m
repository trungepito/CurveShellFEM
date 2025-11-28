function values = recoverNodalSmooth(obj, type, layer)
% SMOOTHING ALGORITHM:
% 1. Loop over elements
% 2. Calculate value at each node of the element
% 3. Add to global node accumulator
% 4. Divide by number of elements connected to that node

nodes = obj.Model.Mesh.Nodes;
nNodes = size(nodes, 1);

global_sum = zeros(nNodes, 1);
node_count = zeros(nNodes, 1);

elems = obj.Model.Mesh.Elements;
U = obj.Solver.U;

% Determine z-coordinate for layer
h = obj.Model.Material.t;
if strcmp(layer, 'Top'), z_loc = h/2;
elseif strcmp(layer, 'Bot'), z_loc = -h/2;
else, z_loc = 0;
end

% Loop Elements
for e = 1:size(elems, 1)
    idx = elems(e, :);
    el_nodes = nodes(idx, :);
    el_norms = obj.Model.Mesh.Normals(idx, :);

    % Element Displacements
    u_el = zeros(40,1);
    for n=1:8, u_el((n-1)*5+(1:5)) = U((idx(n)-1)*5+(1:5)); end

    % Create temporary element to do the math
    % Note: If Plastic, we need history. For plotting, we might
    % approximate plastic strain from the nearest Gauss point.
    mat = obj.Model.Material;

    % For plotting, we create a 'Linear' element just to access
    % B-matrices at NODAL locations (xi, eta = -1, 1...)
    elObj = Curve8Element(el_nodes, el_norms, mat.t, mat.E, mat.nu);

    % Loop over the 8 nodes of this element
    % Natural coords of the 8 nodes
    xi_n  = [-1,  1,  1, -1,  0,  1,  0, -1];
    eta_n = [-1, -1,  1,  1, -1,  0,  1,  0];

    for n = 1:8
        gNodeID = idx(n);

        % Evaluate Strains/Stresses AT THE NODE
        % (This is an extrapolation from Gauss points in theory,
        % but direct evaluation is acceptable for visualization)
        [val, ~] = obj.evaluatePoint(elObj, u_el, xi_n(n), eta_n(n), z_loc, type, e);

        global_sum(gNodeID) = global_sum(gNodeID) + val;
        node_count(gNodeID) = node_count(gNodeID) + 1;
    end
end

% Average
node_count(node_count==0) = 1; % Avoid divide by zero
values = global_sum ./ node_count;
end