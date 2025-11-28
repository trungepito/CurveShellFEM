function [val, tensor] = evaluatePoint(obj, elObj, u_el, xi, eta, z, type, elemID)
% Helper to calculate physics at a specific (xi, eta, z)

% 1. Kinematics
[~, dN_dxi, dN_deta] = elObj.getShapeFunctions(xi, eta);
% ... (Recalculate J, Bm, Bb, Bs, etc here) ...
% To save space, assuming a helper method "getStrainAtPoint" exists or copy logic
% [eps_m, kappa, gamma] = elObj.getStrains(xi, eta, u_el);

% --- ABBREVIATED KINEMATICS FOR DISPLAY ---
% You must copy the B-Matrix generation logic here
% or make it a public method in Curve8Element.
% Let's assume we have calculated strains:
% eps_total = eps_m + z * kappa;

% Placeholder Logic for the example:
eps_total = [0;0;0]; % Replace with real calculation!

% 2. Constitutive
D_el = elObj.getConstitutiveMatrix();
sigma = D_el(1:3,1:3) * eps_total;

% Handle Plasticity for 'PlasticStrain'
% Plastic strain is stored at GAUSS POINTS, not Nodes.
% We must find the closest Gauss point to this node.
ep_val = 0;
if isa(obj.Solver, 'FEM_Solver_Plastic')
    % Grab history from central Gauss point for simplicity
    % or nearest neighbor.
    hist = obj.Solver.GlobalHistory{elemID};
    ep_val = hist(1).eps_p; % Taking first GP as approx
end

% 3. Select Output
switch type
    case 'SigmaX', val = sigma(1);
    case 'SigmaY', val = sigma(2);
    case 'TauXY',  val = sigma(3);
    case 'VonMises'
        vm = sqrt(sigma(1)^2 + sigma(2)^2 - sigma(1)*sigma(2) + 3*sigma(3)^2);
        val = vm;
    case 'PlasticStrain'
        val = ep_val;
    otherwise, val = 0;
end
end