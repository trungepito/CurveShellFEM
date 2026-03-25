
function generateFlatPlate(obj, Lx, Ly, Nu, Nv)
% Generates a rectangular plate in the XY plane (Z=0)
% Lx, Ly: Dimensions
% Nu, Nv: Number of elements in X and Y

% 1. Create Grid
x_lin = linspace(0, Lx, 2*Nu+1);
y_lin = linspace(0, Ly, 2*Nv+1);
[X, Y] = meshgrid(x_lin, y_lin);
Z = zeros(size(X));

% 2. Create Nodes
[nRows, nCols] = size(X);
node_map = zeros(nRows, nCols);
new_nodes = [];
cnt = 0;
base_id = size(obj.Mesh.Nodes, 1);

for j = 1:nCols
    for i = 1:nRows
        % Skip center nodes (Even, Even) indices
        if ~(mod(i,2)==0 && mod(j,2)==0)
            cnt = cnt + 1;
            new_nodes(cnt, :) = [X(i,j), Y(i,j), Z(i,j)];
            node_map(i,j) = base_id + cnt;
        end
    end
end
obj.Mesh.Nodes = [obj.Mesh.Nodes; new_nodes];

% 3. Create Elements
new_elems = zeros(Nu*Nv, 8);
el_cnt = 0;
for v = 1:Nv
    for u = 1:Nu
        % Grid indices: i=Row(Y), j=Col(X)
        r = 2*v - 1;
        c = 2*u - 1;

        % Node Mapping (Standard CCW)
        % 1(BL), 2(BR), 3(TR), 4(TL)
        n1=node_map(r,c);   n2=node_map(r,c+2);   n3=node_map(r+2,c+2); n4=node_map(r+2,c);
        n5=node_map(r,c+1); n6=node_map(r+1,c+2); n7=node_map(r+2,c+1); n8=node_map(r+1,c);

        el_cnt = el_cnt + 1;
        new_elems(el_cnt, :) = [n1,n2,n3,n4,n5,n6,n7,n8];
    end
end
obj.Mesh.Elements = [obj.Mesh.Elements; new_elems];
obj.computeNormals();
end

