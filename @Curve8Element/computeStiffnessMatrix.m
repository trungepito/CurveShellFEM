function Ke = computeStiffnessMatrix(obj)
Ke = zeros(40, 40); % 8 nodes * 5 DOFs

% Gaussian Quadrature
% 3x3 rule is recommended for 8-node elements to prevent hour-glassing
% though 2x2 is sometimes used for shear to prevent locking.
% Here we use 3x3 for simplicity.
g_points = [-sqrt(0.6), 0, sqrt(0.6)];
g_weights = [5/9, 8/9, 5/9];

[D_mb, D_s] = obj.getConstitutiveMatrix();

for i = 1:3
    for j = 1:3
        xi = g_points(i);
        eta = g_points(j);
        w = g_weights(i) * g_weights(j);
        [Bm,Bb,Bs,detJ]=obj.formB(xi,eta);
        % Integration through thickness
        % Stiffness = B_m' * D_m * B_m * t + B_b' * D_b * B_b * (t^3/12) + Shear

        h = obj.Thickness;

        % Membrane Stiffness (Constant through thickness)
        Km = Bm' * D_mb * Bm * h;

        % Bending Stiffness (z^2 integral -> h^3/12)
        Kb = Bb' * D_mb * Bb * (h^3 / 12);

        % Shear Stiffness (Constant through thickness * shear correction)
        Ks = Bs' * D_s * Bs * h;

        % Total Element Stiffness contribution at this Gauss point
        Ke = Ke + (Km + Kb + Ks) * detJ * w;
    end
end
end

