function Kg = computeGeometricStiffness(obj, u_elem,opts)
% Requires the displacement vector u_elem from the static solution
% to calculate the existing membrane forces.
% this Kg is calculated without thickness itegration!, just on the plane
if nargin==2
    opts=[1 1 1;
          1 1 1;
          1 1 1];
    % this opt shows which Green-lagrange term is taken into account
end
Kg = zeros(40, 40);
nGauss=2;
[g_points,g_weights]=MathFEM.Gauss_p(nGauss);

% 1. Get Membrane Forces at Center (Simplified: Assumed constant for element)
res = obj.computeStresses(u_elem);
N_vec = res.MembraneForces; % [Nx; Ny; Nxy]

% Stress Matrix S
% S = [N_vec(1), N_vec(3);
%     N_vec(3), N_vec(2)];

% 2. Integration Loop
for i = 1:nGauss
    for j = 1:nGauss
        xi = g_points(i); eta = g_points(j);
        w=g_weights(i)*g_weights(j);
        [N, der] = obj.fmisoq8(xi, eta);
        % 1. Reconstruct Jacobian and Local Frame (Copy logic from Stiffness)
        % J_vec = [0,0,0; 0,0,0];
        V3_int  = N*obj.Normals;
        J_vec=der*obj.Coords;
        V3_int = V3_int / norm(V3_int);
        v1 = J_vec(1,:) / norm(J_vec(1,:));
        v3 = V3_int;
        v2 = cross(v3, v1); v2 = v2/norm(v2);
        v1 = cross(v2, v3);
        theta = [v1; v2; v3];

        % Local Jacobian
        J_glob_surf = J_vec;
        J_loc = zeros(2,2);
        J_loc(1,1) = dot(J_glob_surf(1,:), v1);
        J_loc(1,2) = dot(J_glob_surf(1,:), v2);
        J_loc(2,1) = dot(J_glob_surf(2,:), v1);
        J_loc(2,2) = dot(J_glob_surf(2,:), v2);
        detJ=det(J_loc);
        invJ = J_loc\eye(2);
        dNd_local = invJ * der;
        % --- REPEAT FRAME LOGIC END ---
        G=zeros(3,2,40);
        % Fill G Matrix
        for n = 1:8
            idx = (n-1)*5 + (1:5);
            dN_dx = dNd_local(1,n);
            dN_dy = dNd_local(2,n);
            
            % We approximate that buckling is driven by derivatives of translations
            % projected onto the local normal (w).
            % u,v,w_local approx = theta(i,1)*u + theta(i,2)*v + theta(i,3)*w
            % Terms for u, v, w
            G(1,1, idx(1:3)) = dN_dx * theta(1, :); % Gux
            G(1,2, idx(1:3)) = dN_dy * theta(1, :); % Guy
            G(2,1, idx(1:3)) = dN_dx * theta(2, :); % Gvx
            G(2,2, idx(1:3)) = dN_dy * theta(2, :); % Gvy
            G(3,1, idx(1:3)) = dN_dx * theta(3, :); % Gwx
            G(3,2, idx(1:3)) = dN_dy * theta(3, :); % Gwy
        end
        for iopt=1:3
            S=opts(:,1).*N_vec;
            Sm=[S(1) S(3); S(3) S(2)];
            Gi=reshape(G(iopt,:,:),[],40);
            Kg = Kg + Gi' * Sm * Gi * detJ*w;
        end
    end
end
end