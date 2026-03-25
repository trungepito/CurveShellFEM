function applyUniformPressure(obj, pressureVec)
% Applies constant pressure to ALL elements
% pressureVec: [Px, Py, Pz] (Force per Area)

fprintf('Applying Uniform Pressure [%g %g %g]...\n', pressureVec);
nNodes = size(obj.Mesh.Nodes, 1);
global_F = zeros(nNodes, 3);

% Integration Rule
g_pt = [-0.7746, 0, 0.7746];
g_wt = [0.5556, 0.8889, 0.5556];

for e = 1:size(obj.Mesh.Elements, 1)
    idx = obj.Mesh.Elements(e, :);
    el_c = obj.Mesh.Nodes(idx, :);

    for i=1:3
        for j=1:3
            xi = g_pt(i); eta = g_pt(j); w = g_wt(i)*g_wt(j);

            [N, der] = Curve8Element.fmisoq8(xi, eta);

            % Jacobian for Area scaling
            t1 = der(1,:)* el_c;
            t2 = der(2,:) * el_c;
            n_vec = cross(t1, t2);
            dA = norm(n_vec);

            % Force Calculation
            % F = N' * P * dA * weight
            f_contrib = (N' * pressureVec) * dA * w;

            global_F(idx, :) = global_F(idx, :) + f_contrib;
        end
    end
end

% Add to Loads List
[rw, cl, val] = find(global_F);
obj.Loads = [obj.Loads; [rw, cl, val]];
end