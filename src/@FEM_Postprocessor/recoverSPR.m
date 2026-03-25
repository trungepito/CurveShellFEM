function values = recoverSPR(obj, type, layer)
% Superconvergent Patch Recovery (SPR)
% Samples stresses at Gauss points and fits a local 3D polynomial.

nodes = obj.Model.Mesh.Nodes;
nNodes = size(nodes, 1);
elems = obj.Model.Mesh.Elements;
nElems = size(elems, 1);
U_global = obj.Solver.U;

% 1. Sample all Gauss points
fprintf('[Post] SPR: Sampling Gauss points...\n');
gps_val = zeros(nElems, 4); 
gps_coords = zeros(nElems, 4, 3);
z_loc = 0; 

h = obj.Model.Material.t;
if strcmp(layer, 'Top'), z_loc = h/2;
elseif strcmp(layer, 'Bot'), z_loc = -h/2;
end

% Standard 2x2 Gauss points
xi_g = [-1/sqrt(3), 1/sqrt(3), 1/sqrt(3), -1/sqrt(3)];
eta_g = [-1/sqrt(3), -1/sqrt(3), 1/sqrt(3), 1/sqrt(3)];

for e = 1:nElems
    if ~isempty(obj.Solver.Elements)
        elObj = obj.Solver.Elements{e};
    else
        idx = elems(e, :);
        elObj = Curve8Element(nodes(idx, :), obj.Model.Mesh.Normals(idx, :), ...
                             obj.Model.Material.t, obj.Model.Material.E, obj.Model.Material.nu);
    end
    
    idx = elems(e, :);
    u_el_g = zeros(48,1);
    for n=1:8, u_el_g((n-1)*6+(1:6)) = U_global((idx(n)-1)*6+(1:6)); end
    
    u_el_l = elObj.T_cached * u_el_g;
    u_el_l(6:6:end) = [];
    u_el = elObj.per_5_blkdiag() * u_el_l;

    for g = 1:4
        [val, ~] = obj.evaluatePoint(elObj, u_el, xi_g(g), eta_g(g), z_loc, type, e);
        gps_val(e, g) = val;
        
        [N, ~, ~] = elObj.getShapeFunctions(xi_g(g), eta_g(g));
        gps_coords(e, g, :) = N * nodes(idx, :);
    end
end

% 2. Patch-wise Nodal Recovery
fprintf('[Post] SPR: Fitting nodal patches...\n');
values = zeros(nNodes, 1);

for n = 1:nNodes
    [con_elems, ~] = find(elems == n);
    X = []; % Coordinates [1, x, y, z]
    Y = []; % Stress values
    
    for e_idx = 1:length(con_elems)
        e = con_elems(e_idx);
        for g = 1:4
            X = [X; 1, gps_coords(e, g,1), gps_coords(e, g,2), gps_coords(e, g,3)]; 
            Y = [Y; gps_val(e, g)];
        end
    end
    
    % Use pinv (pseudo-inverse) for robustness against singular patches (e.g. flat surfaces)
    if size(X, 1) >= 4
        beta = pinv(X) * Y;
        values(n) = [1, nodes(n, 1), nodes(n, 2), nodes(n, 3)] * beta;
    else
        values(n) = mean(Y);
    end
end
fprintf('[Post] SPR: Recovery complete.\n');
end
