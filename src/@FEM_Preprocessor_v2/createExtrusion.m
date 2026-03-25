% --- GENERAL EXTRUSION ENGINE ---
function createExtrusion(obj, profileNodes, profileSegs, direction, extrudeSpecs, meshDensityZ)
% profileNodes: Nx3 Matrix of [x,y,z] for the cross-section
% profileSegs: Mx4 Cell Array or Struct defining connectivity
%              (Node1, Node2, 'type', Nu_elements)
%              For arcs: (Node1, Node2, 'arc', Nu_elements, CenterNodeID_in_Profile)
% direction: [dx, dy, dz] vector (normalized internally)
% extrudeSpecs:
%    - Option A (Array): [L1, L2, L3] -> Extrudes specific lengths
%    - Option B (Scalar): L_total -> Requires meshDensityZ to split
% meshDensityZ: (Optional) Integer.
%    - If extrudeSpecs is Array, this is vector of elements per segment.
%    - If extrudeSpecs is Scalar, this is total elements along L.

% 1. Parse Inputs
dir = direction / norm(direction);

% Determine Layers (Geometric Slices)
if length(extrudeSpecs) > 1
    % User provided specific segment lengths [L1, L2, L3...]
    layer_lengths = extrudeSpecs;
    if nargin < 6, meshDensityZ = ones(1, length(layer_lengths)); end
    if isscalar(meshDensityZ), meshDensityZ = repmat(meshDensityZ, 1, length(layer_lengths)); end
else
    % User provided Total Length
    L_total = extrudeSpecs;
    n_layers = 1;
    if nargin >= 6, n_layers = max(1, meshDensityZ); end
    % Divide into equal geometric chunks (or just 1 chunk meshed finely)
    % Strategy: Create 1 geometric patch of length L, and mesh with N elements.
    layer_lengths = L_total;
    meshDensityZ = n_layers;
end

% 2. Create Base Profile Points (Layer 0)
% Returns a map from Local Profile ID -> Global GeoPoint ID
base_pIDs = zeros(size(profileNodes, 1), 1);
for i = 1:size(profileNodes, 1)
    base_pIDs(i) = obj.addKeypoint(profileNodes(i,:));
end

% Current "Active" points (Bottom of the current slice)
current_pIDs = base_pIDs;
current_coords = profileNodes;

% 3. Extrusion Loop
for k = 1:length(layer_lengths)
    len = layer_lengths(k);
    n_elems_z = meshDensityZ(k);

    % Calculate Next Layer Coords
    next_coords = current_coords + (dir * len);

    % Create Next Layer Points
    next_pIDs = zeros(size(profileNodes, 1), 1);
    for i = 1:size(profileNodes, 1)
        next_pIDs(i) = obj.addKeypoint(next_coords(i,:));
    end

    % Process Each Segment in the Profile
    for s = 1:size(profileSegs, 1)
        % Extract Segment Info
        n1_loc = profileSegs(s, 1);
        n2_loc = profileSegs(s, 2);
        Nu     = profileSegs(s, 4); % Elements along profile

        % Global Point IDs
        p1_bot = current_pIDs(n1_loc);
        p2_bot = current_pIDs(n2_loc);
        p1_top = next_pIDs(n1_loc);
        p2_top = next_pIDs(n2_loc);

        % 1. Create Longitudinal Lines (Rails)
        l_rail1 = obj.addLine(p1_top, p1_bot, 'straight');
        l_rail2 = obj.addLine(p2_bot, p2_top, 'straight');

        % 2. Create Cross-Section Lines (Bot and Top)
        if profileSegs(s, 3)==0
            l_bot = obj.addLine(p1_bot, p2_bot, 'straight');
            l_top = obj.addLine(p2_top, p1_top, 'straight');
        else
            % Handle Arc Center Extrusion
            c_loc = profileSegs(s, 3);

            % Center Base
            p_c_base = current_pIDs(c_loc);
            % Center Top (Need to create it if it wasn't part of the main profile nodes,
            % but typically centers are in the node list for robustness)
            p_c_top = next_pIDs(c_loc);

            l_bot = obj.addLine(p1_bot, p2_bot, 'arc', p_c_base);
            l_top = obj.addLine(p2_top, p1_top, 'arc', p_c_top);
        end

        % 3. Create Patch
        % Loop: Bottom -> Right Rail -> Top(rev) -> Left Rail(rev)
        % Standard Coons: l1(u), l2(v), l3(u), l4(v)
        % Here: Bot, Rail2, Top, Rail1
        pid = obj.addPatch(l_bot, l_rail2, l_top, l_rail1);

        % 4. Auto-Mesh
        obj.meshQuadPatch(pid, Nu, n_elems_z);
    end

    % Advance
    current_pIDs = next_pIDs;
    current_coords = next_coords;
end

% Fuse nodes generated at patch boundaries
obj.fuseNodes(1e-5);
obj.computeNormals();
end