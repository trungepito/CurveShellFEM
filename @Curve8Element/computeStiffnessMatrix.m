function Ke = computeStiffnessMatrix(obj)
Ke = zeros(40, 40); % 8 nodes * 5 DOFs

% Gaussian Quadrature
% 3x3 rule is recommended for 8-node elements to prevent hour-glassing
% though 2x2 is sometimes used for shear to prevent locking.
% Here we use 3x3 for simplicity
[D_mb, D_s] = obj.getConstitutiveMatrix();
Gpoint_mb=3;% number of gauss points for Membrane and Bending term
Gpoint_s=2; % number of gauss points for Shear term

[g_points,g_weights]=MathFEM.Gauss_p(Gpoint_mb);
for i = 1:Gpoint_mb
    for j = 1:Gpoint_mb
        xi = g_points(i);
        eta = g_points(j);
        w = g_weights(i) * g_weights(j);
        [Bm,Bb,detJ]=obj.formBmb(xi,eta);
        % Integration through thickness
        % Stiffness = B_m' * D_m * B_m * t + B_b' * D_b * B_b * (t^3/12) + Shear

        h = obj.Thickness;

        % Membrane Stiffness (Constant through thickness)
        Km = Bm' * D_mb * Bm * h;

        % Bending Stiffness (z^2 integral -> h^3/12)
        Kb = Bb' * D_mb * Bb * (h^3 / 12);

        % Shear Stiffness (Constant through thickness * shear correction)
        % Ks = Bs' * D_s * Bs * h;

        % Total Element Stiffness contribution at this Gauss point
        Ke = Ke + (Km + Kb ) * detJ * w;
    end
end

% Shear term
[g_points,g_weights]=MathFEM.Gauss_p(Gpoint_s);
for i = 1:Gpoint_s
    for j = 1:Gpoint_s
        xi = g_points(i);
        eta = g_points(j);
        w = g_weights(i) * g_weights(j);
        [Bs,detJ]=obj.formBs(xi,eta);
        % Integration through thickness
        % Stiffness = B_m' * D_m * B_m * t + B_b' * D_b * B_b * (t^3/12) + Shear
        h = obj.Thickness;
        % Membrane Stiffness (Constant through thickness)
        % Bending Stiffness (z^2 integral -> h^3/12)
        % Shear Stiffness (Constant through thickness * shear correction)
        Ks = Bs' * D_s * Bs * h;
        % Total Element Stiffness contribution at this Gauss point
        Ke = Ke + Ks* detJ * w;
    end
end

end

