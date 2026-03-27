function values = recoverNodalStressSPR(obj, type, layer)
% RECOVERNODALSTRESSSPR - Superconvergent Patch Recovery (SPR) for shell stress.
% type: 'SigmaX', 'SigmaY', 'TauXY', 'VonMises'
% layer: 'Mid', 'Top', 'Bot'

if nargin < 3, layer = 'Mid'; end
z_val = 0;
if strcmp(layer, 'Top'), z_val = 0.5 * obj.Model.Material.t; end
if strcmp(layer, 'Bot'), z_val = -0.5 * obj.Model.Material.t; end

nNodes = size(obj.Model.Mesh.Nodes, 1);
nElems = size(obj.Model.Mesh.Elements, 1);
elems  = obj.Model.Mesh.Elements;
nodes  = obj.Model.Mesh.Nodes;

% 1. Map: Node -> List of adjacent elements
node2elems = cell(nNodes, 1);
for e = 1:nElems
    for n = 1:8
        nid = elems(e, n);
        node2elems{nid} = [node2elems{nid}; e];
    end
end

% 2. Sample Gauss points (Superconvergent points)
% For 8-node elements, 2x2 points (xi,eta = +/- 1/sqrt(3)) are superconvergent.
gp = 1/sqrt(3);
xi_g  = [-gp,  gp,  gp, -gp];
eta_g = [-gp, -gp,  gp,  gp];
nGP = 4;

values = zeros(nNodes, 1);

for i = 1:nNodes
    patch_elems = node2elems{i};
    if isempty(patch_elems), continue; end
    
    % Collect all GP data in this patch
    X_patch = []; Y_patch = []; S_patch = [];
    
    for e = patch_elems'
        elObj = obj.Solver.Elements{e};
        u_el = obj.Solver.U(obj.Solver.SctrMap(e, :));
        
        [~, ~, ~, N_all] = elObj.calculateKinematics(xi_g, eta_g);
        coords_el = obj.Model.Mesh.Nodes(elems(e, 1:8), :);
        
        for k = 1:nGP
            % Global coordinates of GP
            gp_pos = N_all(k, :) * coords_el; 
            [sig_val, ~] = obj.evaluatePoint(elObj, u_el, xi_g(k), eta_g(k), z_val, type, e);
            
            X_patch = [X_patch; gp_pos(1)];
            Y_patch = [Y_patch; gp_pos(2)];
            S_patch = [S_patch; sig_val];
        end
    end
    
    % Linear Polynomial Fit: s = a1 + a2*x + a3*y
    % Solve: [1, x, y] * [a1; a2; a3] = S
    P = [ones(size(X_patch)), X_patch, Y_patch];
    
    if size(P, 1) >= 3
        a = (P' * P) \ (P' * S_patch);
        % Evaluate at node i
        node_pos = nodes(i, :);
        values(i) = [1, node_pos(1), node_pos(2)] * a;
    else
        % Fallback to average if patch is too small
        values(i) = mean(S_patch);
    end
end
end
