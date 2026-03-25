function meshQuadPatch(obj, patchID, Nu, Nv)
% Meshes a 4-sided patch into Nu x Nv 8-node elements
% Uses Transfinite Interpolation (Linear Blending)
% For the 8 nodes elements, eliminate the node 9th is crucial in the whole
% procedure
patch = obj.GeoPatches{patchID};
lines = patch.lines;

% 1. Discretize the 4 boundary lines
% We need 2*Nu+1 points along u-direction lines
% We need 2*Nv+1 points along v-direction lines

nPtsU = 2*Nu + 1;
nPtsV = 2*Nv + 1;

% Get coordinates of boundary curves
% Note: In a real CAD kernel, we check orientation.
% Here we assume lines are ordered: Bottom, Right, Top, Left.
CurveB = obj.discretizeLine(lines(1), nPtsU); % Bottom (u varying)
CurveR = obj.discretizeLine(lines(2), nPtsV); % Right (v varying)
CurveT = obj.discretizeLine(lines(3), nPtsU); % Top (u varying, reversed)
CurveL = obj.discretizeLine(lines(4), nPtsV); % Left (v varying, reversed)

% Flip Top and Left to align with parametric direction if needed
% (Assuming standard CCW loop: B->, R^, T<-, Lv)
% Mapping requires T to go Left->Right and L to go Bottom->Top mathematically
CurveT = flipud(CurveT);
CurveL = flipud(CurveL);

% 2. Generate Internal Grid (Coons Patch Interpolation)
% P(u,v) = (1-v)P_bottom(u) + v*P_top(u) + (1-u)P_left(v) + u*P_right(v)
%          - [Bilinear interpolation of corners]

u = linspace(0, 1, nPtsU);
v = linspace(0, 1, nPtsV);

temp_nodes = zeros(nPtsV, nPtsU, 3);
node_ids_local = zeros(nPtsV, nPtsU);

% Corner coords
C00 = CurveB(1,:); C10 = CurveB(end,:);
C01 = CurveT(1,:); C11 = CurveT(end,:);

base_node_id = size(obj.Mesh.Nodes, 1);
count=0;
for j = 1:nPtsV
    for i = 1:nPtsU
        if ~(mod(i,2)==0 && mod(j,2)==0)
            uu = u(i); vv = v(j);

            % Boundary Interpolations
            P_b = CurveB(i,:);
            P_t = CurveT(i,:);
            P_l = CurveL(j,:);
            P_r = CurveR(j,:);

            % Bilinear Corner Blend
            P_bilinear = (1-uu)*(1-vv)*C00 + uu*(1-vv)*C10 + ...
                (1-uu)*vv*C01     + uu*vv*C11;

            % Coons Formula
            Coord = (1-vv)*P_b + vv*P_t + (1-uu)*P_l + uu*P_r - P_bilinear;
            count=count+1;
            obj.Mesh.Nodes(end+1, :) = Coord;
            node_ids_local(j,i) = base_node_id + count;
        end
    end
end

% 3. Create Elements from the Grid
for j = 1:Nv
    for i = 1:Nu
        r = 2*j - 1;
        c = 2*i - 1;

        % 8-Node Connectivity (Grid indices)
        % 4 Corners
        n1 = node_ids_local(r,   c);
        n2 = node_ids_local(r,   c+2);
        n3 = node_ids_local(r+2, c+2);
        n4 = node_ids_local(r+2, c);
        % 4 Midsides
        n5 = node_ids_local(r,   c+1);
        n6 = node_ids_local(r+1, c+2);
        n7 = node_ids_local(r+2, c+1);
        n8 = node_ids_local(r+1, c);

        obj.Mesh.Elements(end+1, :) = int32([n1,n2,n3,n4,n5,n6,n7,n8]);
    end
end
end