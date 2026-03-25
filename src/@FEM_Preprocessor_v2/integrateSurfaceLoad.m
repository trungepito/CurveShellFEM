function integrateSurfaceLoad(obj, elemIDs, funcHandle, type,tag)
% Integrates load over elements
% type: 'cartesian' (func returns [Fx;Fy;Fz])
%       'normal'    (func takes normal, returns [Fx;Fy;Fz])
%       'cylindrical' (handled separately or wrapped)

fprintf('[Physics] Integrating loads on %d elements...\n', length(elemIDs));

g_pt = [-0.7746, 0, 0.7746];
g_wt = [0.5556, 0.8889, 0.5556];

global_F = zeros(size(obj.Mesh.Nodes,1), 3);

for k = 1:length(elemIDs)
    eID = elemIDs(k);
    idx = obj.Mesh.Elements(eID, :);
    el_c = obj.Mesh.Nodes(idx, :);

    for i=1:3
        for j=1:3
            xi=g_pt(i); eta=g_pt(j); w=g_wt(i)*g_wt(j);
            [N, der] = Curve8Element.fmisoq8(xi, eta);

            % Geometry
            t1 = der(1,:) * el_c; t2 = der(2,:) * el_c;
            n_vec = cross(t1, t2);
            dA = norm(n_vec);
            n_unit = n_vec / dA;

            % Evaluate Load Vector
            if strcmp(type, 'normal')
                F_vec = funcHandle(n_unit); % P * n
            elseif strcmp(type, 'cartesian')
                F_vec = funcHandle(); % Constant vector
            end

            % Consistent Nodal Load
            % f = N^T * F_vec * dA
            f_contrib = (N' * F_vec(:)') * dA * w;
            global_F(idx, :) = global_F(idx, :) + f_contrib;
        end
    end
end

% Store
[r, c, v] = find(global_F);
obj.Loads = [obj.Loads; {r, c, v, tag}];
end