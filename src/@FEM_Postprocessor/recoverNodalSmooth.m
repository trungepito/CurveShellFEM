function values = recoverNodalSmooth(obj, type, layer)
% RECOVERNODALSMOOTH - Vectorized Nodal Recovery for CurveShellFEM.
%
% Performs high-speed Superconvergent Recovery (SPR) of results. This 
% function is fully vectorized across all elements for real-time performance.
%
% Syntax:
%   values = recoverNodalSmooth(obj, FieldType, Layer)
%
% Inputs:
%   FieldType - 'Displacement', 'SigmaX', 'SigmaY', 'TauXY', 'VonMises', 
%               'PrincipalStress1', 'PrincipalStress2'
%   Layer     - 'Top', 'Mid', 'Bot', or 'All'
%
% Outputs:
%   values    - [nNodes x nLayers] Array of recovered nodal results.

nodes = obj.Model.Mesh.Nodes;
nNodes = size(nodes, 1);
elems = obj.Model.Mesh.Elements;
nElems = size(elems, 1);
U = obj.Solver.U;

% Determine Layers
h = obj.Model.Material.t;
E = obj.Model.Material.E;
nu = obj.Model.Material.nu;
if iscell(layer)
    layers_to_scan = layer;
elseif strcmp(layer, 'All')
    layers_to_scan = {'Bot', 'Mid', 'Top'};
else
    layers_to_scan = {layer};
end
nLayers = length(layers_to_scan);
z_locs = zeros(1, nLayers);
for l = 1:nLayers
    if strcmp(layers_to_scan{l}, 'Top'), z_locs(l) = h/2;
    elseif strcmp(layers_to_scan{l}, 'Bot'), z_locs(l) = -h/2;
    else, z_locs(l) = 0; end
end

% Constitutive matrix D_mb (Membrane/Bending) and D_s (Shear)
factor = E / (1 - nu^2);
D_mb = factor * [1, nu, 0; nu, 1, 0; 0, 0, (1-nu)/2];
% D_s = E / (2 * (1 + nu)) * (5/6) * eye(2); % Using analytical D_mb for stresses

% Superconvergent Recovery: 4 Gauss points -> 8 Nodes
gp = 1/sqrt(3);
xi_g  = [-gp,  gp,  gp, -gp];
eta_g = [-gp, -gp,  gp,  gp];

% Extrapolation Matrix (4 Gauss points -> 8 Nodes)
% For an 8-node element, we extrapolate from 2x2 Gauss points to the 8 nodal locations
E = zeros(8, 4);
xi_n  = [-1,  1,  1, -1,  0,  1,  0, -1];
eta_n = [-1, -1,  1,  1, -1,  0,  1,  0];
for i = 1:8
    for j = 1:4
        % Linear extrapolation from square defined by Gauss points
        E(i,j) = 0.25 * (1 + xi_n(i)*xi_g(j)*3) * (1 + eta_n(i)*eta_g(j)*3);
    end
end

% Precompute shape functions at 4 Gauss points
N_g = zeros(4, 8);
der_g = zeros(4, 2, 8);
for g = 1:4
    [N_val, der_val] = Curve8Element.fmisoq8(xi_g(g), eta_g(g));
    N_g(g, :) = N_val;
    der_g(g, :, :) = der_val;
end

% Pre-extract all element coordinates and normals
el_Coords = nodes(elems', :); % [8*nElems x 3]
el_Coords = reshape(el_Coords, 8, nElems, 3);
el_Normals = obj.Model.Mesh.Normals(elems', :); % [8*nElems x 3]
el_Normals = reshape(el_Normals, 8, nElems, 3);

% Extract Global U and map to Mixed Basis (40) for all elements
u_g_all = zeros(48, nElems);
for k = 1:8
    node_idx = double(elems(:,k));
    dof_idx = (node_idx-1)*6;
    for d = 1:6
        u_g_all((k-1)*6 + d, :) = U(dof_idx + d);
    end
end

% Vectorized Transform to Mixed Basis
el_U = zeros(40, nElems);
% Get the transformation operator from the first element (common formulation)
per5 = obj.Solver.Elements{1}.per_5_blkdiag(); 
for e = 1:nElems
    u_l = obj.Solver.Elements{e}.T_cached * u_g_all(:, e);
    u_l(6:6:end) = []; 
    el_U(:, e) = per5 * u_l;
end

% Preallocate Result for 8 nodes per element
val_accum = zeros(8 * nElems, nLayers);

% --- Main Vectorized Calculation (Across 4 Gauss Points) ---
for g = 1:4
    N_val = N_g(g, :);
    der_val = squeeze(der_g(g, :, :)); % [2 x 8]
    
    % 1. Kinematics (All elements at once)
    % J_vec = der_val * Cb -> [2 x 8] * [8 x nElems x 3]
    J_vec_x = der_val * squeeze(el_Coords(:,:,1)); % [2 x nElems]
    J_vec_y = der_val * squeeze(el_Coords(:,:,2));
    J_vec_z = der_val * squeeze(el_Coords(:,:,3));
    
    % V3_int (Normal at GP)
    V3_x = N_val * squeeze(el_Normals(:,:,1)); % [1 x nElems]
    V3_y = N_val * squeeze(el_Normals(:,:,2));
    V3_z = N_val * squeeze(el_Normals(:,:,3));
    v3 = [V3_x', V3_y', V3_z'];
    v3 = v3 ./ sqrt(sum(v3.^2, 2)); % Normalize per element
    
    % Local Frame v1, v2, v3
    v1_raw = [J_vec_x(1,:)', J_vec_y(1,:)', J_vec_z(1,:)'];
    v1 = v1_raw ./ sqrt(sum(v1_raw.^2, 2));
    v2 = cross(v3, v1, 2);
    v2 = v2 ./ sqrt(sum(v2.^2, 2));
    v1 = cross(v2, v3, 2);
    
    % J_loc [2 x 2] per element
    J11 = sum([J_vec_x(1,:)', J_vec_y(1,:)', J_vec_z(1,:)'] .* v1, 2);
    J12 = sum([J_vec_x(1,:)', J_vec_y(1,:)', J_vec_z(1,:)'] .* v2, 2);
    J21 = sum([J_vec_x(2,:)', J_vec_y(2,:)', J_vec_z(2,:)'] .* v1, 2);
    J22 = sum([J_vec_x(2,:)', J_vec_y(2,:)', J_vec_z(2,:)'] .* v2, 2);
    
    detJ = J11.*J22 - J12.*J21;
    invJ11 = J22./detJ; invJ12 = -J12./detJ;
    invJ21 = -J21./detJ; invJ22 = J11./detJ;
    
    % dNd_local [2 x 8 x nElems]
    dNd_x = invJ11 .* der_val(1,:) + invJ12 .* der_val(2,:); % [nElems x 8]
    dNd_y = invJ21 .* der_val(1,:) + invJ22 .* der_val(2,:);
    
    % 2. Build Strains (All elements at once)
    eps_m = zeros(3, nElems);
    kappa = zeros(3, nElems);
    
    for k = 1:8
        idxU = (k-1)*5 + (1:3);
        idxR = (k-1)*5 + (4:5);
        
        % Membrane Contribution from Nodal Displacements
        uk = el_U(idxU, :); % [3 x nElems]
        eps_m(1,:) = eps_m(1,:) + dNd_x(:,k)' .* sum(uk' .* v1, 2)';
        eps_m(2,:) = eps_m(2,:) + dNd_y(:,k)' .* sum(uk' .* v2, 2)';
        eps_m(3,:) = eps_m(3,:) + dNd_y(:,k)' .* sum(uk' .* v1, 2)' + dNd_x(:,k)' .* sum(uk' .* v2, 2)';
        
        % Bending Contribution from Nodal Rotations
        % theta_n calculation per node (could be further precomputed)
        V3k_x = squeeze(el_Normals(k,:,1))'; V3k_y = squeeze(el_Normals(k,:,2))'; V3k_z = squeeze(el_Normals(k,:,3))';
        v3k = [V3k_x, V3k_y, V3k_z];
        v3k = v3k ./ sqrt(sum(v3k.^2, 2));
        
        % Nodal local frame v1n, v2n
        isNearY = abs(v3k(:,2)) > 0.9;
        v1n = zeros(nElems, 3);
        v1n(~isNearY, :) = cross(repmat([0 1 0], sum(~isNearY), 1), v3k(~isNearY, :), 2);
        v1n(isNearY, :)  = cross(repmat([1 0 0], sum(isNearY), 1),  v3k(isNearY, :), 2);
        v1n = v1n ./ sqrt(sum(v1n.^2, 2));
        v2n = cross(v3k, v1n, 2);
        
        rk = el_U(idxR, :); % [2 x nElems]
        % alpha = rk(2,:), beta = rk(1,:) in mixed basis
        Pn = sum(v1 .* v1n, 2)'; % theta * v1n' -> we only need row 1,2 of theta
        Qn = -sum(v1 .* v2n, 2)';
        Pm = sum(v2 .* v1n, 2)';
        Qm = -sum(v2 .* v2n, 2)';
        
        kappa(1,:) = kappa(1,:) + dNd_x(:,k)' .* (Pn .* rk(1,:) + Qn .* rk(2,:));
        kappa(2,:) = kappa(2,:) + dNd_y(:,k)' .* (Pm .* rk(1,:) + Qm .* rk(2,:));
        kappa(3,:) = kappa(3,:) + dNd_y(:,k)' .* (Pn .* rk(1,:) + Qn .* rk(2,:)) + ...
                                  dNd_x(:,k)' .* (Pm .* rk(1,:) + Qm .* rk(2,:));
    end
    
    % 3. Stresses & Extrapolation
    for l = 1:nLayers
        eps_total = eps_m + z_locs(l) * kappa;
        sigma = D_mb * eps_total; % [3 x nElems]
        
        switch type
            case 'SigmaX', sig_val = sigma(1,:);
            case 'SigmaY', sig_val = sigma(2,:);
            case 'TauXY',  sig_val = sigma(3,:);
            case 'VonMises', sig_val = sqrt(sigma(1,:).^2 + sigma(2,:).^2 - sigma(1,:).*sigma(2,:) + 3*sigma(3,:).^2);
            case 'PrincipalStress1'
                s_avg = (sigma(1,:) + sigma(2,:))/2; radius = sqrt(((sigma(1,:)-sigma(2,:))/2).^2 + sigma(3,:).^2);
                sig_val = s_avg + radius;
            case 'PrincipalStress2'
                s_avg = (sigma(1,:) + sigma(2,:))/2; radius = sqrt(((sigma(1,:)-sigma(2,:))/2).^2 + sigma(3,:).^2);
                sig_val = s_avg - radius;
            case 'PlasticStrain'
                % Extract p from HistoryData (At specific layer)
                sig_val = zeros(1, nElems);
                layer_idx = 3; % Mid default
                if strcmp(layers_to_scan{l}, 'Top'), layer_idx = 5;
                elseif strcmp(layers_to_scan{l}, 'Bot'), layer_idx = 1; end
                
                for e = 1:nElems
                    if isa(obj.Solver.Elements{e}, 'Curve8Element_Plastic')
                        % GP mapping for Simpson: (g-1)*5 + layer_idx
                        idx_p = (g-1)*5 + layer_idx;
                        sig_val(e) = obj.Solver.Elements{e}.HistoryData(idx_p).p;
                    end
                end
            case 'Displacement', sig_val = NaN(1, nElems);
            otherwise, sig_val = zeros(1, nElems);
        end
        
        % Extrapolate this Gauss point contribution to all 8 nodes of all 1000 elems
        % val_accum is [8*nElems x nLayers]
        % E(n, g) is the weight of gp g for node n
        for n = 1:8
            val_accum(n:8:end, l) = val_accum(n:8:end, l) + E(n, g) * sig_val';
        end
    end
end

% Special case displacement (still nodal direct)
if strcmp(type, 'Displacement')
    for e = 1:nElems
        idx_e = elems(e,:);
        for n = 1:8
            idx_n = idx_e(n);
            u_xyz = [U((idx_n-1)*6+1), U((idx_n-1)*6+2), U((idx_n-1)*6+3)];
            val_accum((e-1)*8 + n, :) = norm(u_xyz);
        end
    end
end

% Assemble globally
values = zeros(nNodes, nLayers);
nodes_flat = double(elems');
nodes_flat = nodes_flat(:);
for l = 1:nLayers
    v = val_accum(:, l);
    values(:, l) = accumarray(nodes_flat, v, [nNodes, 1]) ./ accumarray(nodes_flat, ones(size(v)), [nNodes, 1]);
end

if nLayers == 1
    values = values(:, 1);
end
end