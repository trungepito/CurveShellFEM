function generateCylinderPatch(obj, R, L, Nu, Nv, angleStart, angleEnd)
% Generates a clean 8-node patch

% 1. Create High-Res Grid (2*Nu+1) x (2*Nv+1)
u_lin = linspace(angleStart, angleEnd, 2*Nu+1);
v_lin = linspace(0, L, 2*Nv+1);
[U_grid, V_grid] = meshgrid(u_lin, v_lin);

% 2. Map to Cylinder
X = R * cos(U_grid);
Y = R * sin(U_grid);
Z = V_grid;

% 3. Create Nodes List (Vectorized)
% Identify strictly used nodes (Corners + Mids)
% Map grid indices to Node List Indices
[nRows, nCols] = size(X);
node_map = zeros(nRows, nCols);
new_nodes = [];
cnt = 0;

for j = 1:nCols
    for i = 1:nRows
        % Keep if row/col index is Odd (Corner) or (Odd,Even)/(Even,Odd) (Midside)
        % Skip if Both Even (Center of element
        if ~(mod(i,2)==0 && mod(j,2)==0)
            cnt = cnt + 1;
            new_nodes(cnt, :) = [X(i,j), Y(i,j), Z(i,j)];
            node_map(i,j) = cnt + size(obj.Mesh.Nodes, 1);
        end
    end
end

obj.Mesh.Nodes = [obj.Mesh.Nodes; new_nodes];

% 4. Elements Connectivity
new_elems = zeros(Nu*Nv, 8);
el_cnt = 0;
for v = 1:Nv
    for u = 1:Nu
        % Let's stick to: i=Row(Z), j=Col(Theta)
        r = 2*v - 1;
        c = 2*u - 1;
        n1=node_map(r,c);   n2=node_map(r,c+2);   n3=node_map(r+2,c+2); n4=node_map(r+2,c);
        n5=node_map(r,c+1); n6=node_map(r+1,c+2); n7=node_map(r+2,c+1); n8=node_map(r+1,c);
        el_cnt = el_cnt + 1;
        new_elems(el_cnt, :) = [n1,n2,n3,n4,n5,n6,n7,n8];
    end
end
obj.Mesh.Elements = [obj.Mesh.Elements; new_elems];
obj.computeNormals();
end