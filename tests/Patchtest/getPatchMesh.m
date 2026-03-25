function [Nodes, Elements, BndNodes, IntNodes] = getPatchMesh(nDiv)
% Generates arbitrary quadrilateral patch
P1 = [0.0, 0.0, 0];
P2 = [2.4, 0.2, 0];
P3 = [2.0, 1.8, 0];
P4 = [0.3, 1.5, 0];

u_vals = linspace(-1, 1, 2*nDiv+1);
v_vals = linspace(-1, 1, 2*nDiv+1);

Nodes = [];
node_map = zeros(2*nDiv+1, 2*nDiv+1);
cnt = 0;
% Create Nodes
for j = 1:length(v_vals)
    for i = 1:length(u_vals)
        xi = u_vals(i); eta = v_vals(j);
        N1 = 0.25*(1-xi)*(1-eta); N2 = 0.25*(1+xi)*(1-eta);
        N3 = 0.25*(1+xi)*(1+eta); N4 = 0.25*(1-xi)*(1+eta);
        coord = N1*P1 + N2*P2 + N3*P3 + N4*P4;

        if ~(mod(i,2)==0 && mod(j,2)==0)
            Nodes = [Nodes; coord];
            cnt = cnt + 1;
            node_map(i,j) = 0 + cnt; % only one plate!
        end
    end
end

% Create Elements
Elements = zeros(nDiv*nDiv, 8);
el_cnt = 0;
for v = 1:nDiv
    for u = 1:nDiv
        % Grid indices: i=Row(Y), j=Col(X)
        r = 2*v - 1;
        c = 2*u - 1;
        % Node Mapping (Standard CCW)
        % 1(BL), 2(BR), 3(TR), 4(TL)
        n1=node_map(r,c);   n2=node_map(r,c+2);   n3=node_map(r+2,c+2); n4=node_map(r+2,c);
        n5=node_map(r,c+1); n6=node_map(r+1,c+2); n7=node_map(r+2,c+1); n8=node_map(r+1,c);
        el_cnt = el_cnt + 1;
        Elements(el_cnt, :) = [n1,n2,n3,n4,n5,n6,n7,n8];
    end
end
% Identify Boundary vs Internal
all_indices = node_map(node_map > 0);

% Boundary indices in the grid matrix
bnd_idx = unique([node_map(1,:), node_map(end,:), node_map(:,1)', node_map(:,end)']);
bnd_idx = bnd_idx(bnd_idx > 0);

BndNodes = bnd_idx(:);
IntNodes = setdiff(all_indices, BndNodes);
end