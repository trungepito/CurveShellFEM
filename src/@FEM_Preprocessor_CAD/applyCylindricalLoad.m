function applyCylindricalLoad(obj, elemIDs, loadFunc)
% Applies distributed load defined in Cylindrical Coordinates
% elemIDs: List of elements to apply load to
% loadFunc: Function handle @(r, theta, z) returning [Fr; Ftheta; Fz]
%           Units: Force per Area (Pressure)

fprintf('Integrating Distributed Loads on %d elements...\n', length(elemIDs));

% Gauss Quadrature (3x3 Rule for Surface Integration)
g_pt = [-sqrt(0.6), 0, sqrt(0.6)];
g_wt = [5/9, 8/9, 5/9];

% Temporary storage for nodal force accumulation
% Map: global_force(NodeID, DOF)
maxNode = size(obj.Mesh.Nodes, 1);
global_force = zeros(maxNode, 3);

for k = 1:length(elemIDs)
    eID = elemIDs(k);
    nodes_idx = obj.Mesh.Elements(eID, :);
    el_coords = obj.Mesh.Nodes(nodes_idx, :);

    % We need shape functions. Let's reuse the logic from Curve8Element.
    % Ideally, Curve8Element should have a static method for this,
    % but we can instantiate a lightweight version here.
    % (We don't need material props for geometry)
    elObj = Curve8Element(el_coords, zeros(8,3), 1, 1, 0.3);

    for i = 1:3
        for j = 1:3
            xi = g_pt(i);
            eta = g_pt(j);
            w = g_wt(i) * g_wt(j);

            [N, dN_dxi, dN_deta] = elObj.getShapeFunctions(xi, eta);

            % 1. Interpolate Physical Coordinate (X,Y,Z) at Gauss Point
            xyz_g = N * el_coords;
            X = xyz_g(1); Y = xyz_g(2); Z = xyz_g(3);

            % 2. Convert to Cylindrical (r, theta, z)
            % Standard Math Convention: Theta from X-axis CCW
            r = sqrt(X^2 + Y^2);
            theta = atan2(Y, X);

            % 3. Evaluate User Load Function
            % Returns vector [Fr, Ftheta, Fz] (Pressure)
            P_cyl = loadFunc(r, theta, Z);
            Fr = P_cyl(1); Ft = P_cyl(2); Fz = P_cyl(3);

            % 4. Transform Pressure to Global Cartesian [Px, Py, Pz]
            % Rotation Matrix from Cylindrical to Cartesian
            % [ cos -sin  0 ]
            % [ sin  cos  0 ]
            % [  0    0   1 ]
            c = cos(theta); s = sin(theta);

            Px = Fr*c - Ft*s;
            Py = Fr*s + Ft*c;
            Pz = Fz;

            P_vec = [Px; Py; Pz];

            % 5. Calculate Surface Jacobian (Area Scaling)
            % We need the cross product of the tangent vectors
            t_xi = dN_dxi * el_coords;
            t_eta = dN_deta * el_coords;

            % Normal vector magnitude represents the area stretch (dA/dxdn)
            n_vec = cross(t_xi, t_eta);
            dA = norm(n_vec);

            % 6. Distribute to Nodes
            % Force_node_i = N_i * P_vec * dA * weight
            for n = 1:8
                gNode = nodes_idx(n);
                force_contribution = N(n) * P_vec * dA * w;
                global_force(gNode, :) = global_force(gNode, :) + force_contribution';
            end
        end
    end
end

% Add accumulated forces to the main Loads array
for n = 1:maxNode
    for d = 1:3
        val = global_force(n, d);
        if abs(val) > 1e-10
            obj.Loads = [obj.Loads; n, d, val];
        end
    end
end
end