function [val, tensor] = evaluatePoint(obj, elObj, u_el, xi, eta, z, type, elemID)
% Helper to calculate physics at a specific (xi, eta, z)
val=[];
tensor=[];
% 1. Map Global DOFs (48) to Mixed Basis (40)
T_hybrid = elObj.T_cached;
u_el_l = T_hybrid * u_el;
u_el_l(6:6:end) = []; % Strip drilling
u_mix = elObj.per_5_blkdiag() * u_el_l;

% 2. Kinematics
[Bm_all, Bb_all, ~] = elObj.formBmb(xi, eta);
[Bs_all, ~] = elObj.formBs(xi, eta);
Bm = Bm_all(:,:,1); Bb = Bb_all(:,:,1); Bs = Bs_all(:,:,1);

% 3. Compute Strains
eps_m = Bm * u_mix; % [ex, ey, gxy]
kappa = Bb * u_mix; % [kx, ky, kxy]
gamma = Bs * u_mix; % [gyz, gxz]

% --- ABBREVIATED KINEMATICS FOR DISPLAY ---
% You must copy the B-Matrix generation logic here
% or make it a public method in Curve8Element.
% Let's assume we have calculated strains:
eps_total = eps_m + z * kappa;

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
    case 'PrincipalStress1'
        % Max Principal Stress (2D plane stress approx)
        s_avg = (sigma(1) + sigma(2))/2;
        radius = sqrt(((sigma(1)-sigma(2))/2)^2 + sigma(3)^2);
        val = s_avg + radius;
    case 'PrincipalStress2'
        % Min Principal Stress
        s_avg = (sigma(1) + sigma(2))/2;
        radius = sqrt(((sigma(1)-sigma(2))/2)^2 + sigma(3)^2);
        val = s_avg - radius;
    case 'Pressure'
        % Hydrostatic stress (avg of sigmaX and sigmaY for plane stress)
        val = (sigma(1) + sigma(2))/3; 
    case 'PlasticStrain'
        val = ep_val;
    otherwise, val = 0;
end
end