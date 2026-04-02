% benchmark_scordelis_lo.m
% Scordelis-Lo Roof Benchmark
% Standard shell test for membrane/bending coupling.
clear; clc;

% 1. Parameters (consistent units)
R = 25.0;       % Radius
L_half = 25.0;  % Half-length (for 1/4 model)
theta = 40.0;   % Half-angle in degrees
t = 0.25;       % Thickness
E = 4.32e8;     % Young's Modulus
nu = 0.0;       % Poisson's Ratio
gravity = -90.0; % Surface load (Z direction in local, but we'll use global)

% 2. Mesh setup (1/4 symmetry)
% Profile: One Arc segment in X-Z plane
p_edge = [R * cosd(90-theta), 0, R * sind(90-theta)];
p_peak = [0, 0, R];
p_center = [0, 0, 0];
profile_nodes = [p_edge; p_peak; p_center];

Pre = FEM_Preprocessor_v2(E, nu, t);
% segs: [N1, N2, CenterNode, Nu_elements]
segs = [1, 2, 3, 20]; 
% Extrude along Y (from 0 to 25), with 20 elements along L
Pre.createExtrusion(profile_nodes, segs, [0, 1, 0], L_half, 50);

% 3. BCs (1/4 Symmetry)
% Peak line (X=0): Symmetry about Y-Z plane
peakNodes = Pre.selectNodesByBox(-0.1, 0.1, -1, 30, -1, 30);
Pre.addBC(peakNodes, [1, 5, 6], 0, 'Symm_Peak'); % u_x=0, rot_y=0, rot_z=0

% Mid-span (Y=25): Symmetry about X-Z plane
midNodes = Pre.selectNodesByBox(-1, 30, 24.9, 25.1, -1, 30);
Pre.addBC(midNodes, [2, 4, 6], 0, 'Symm_Mid'); % u_y=0, rot_x=0, rot_z=0

% Diaphragm edge (Y=0): u_x=u_z=0
diaphNodes = Pre.selectNodesByBox(-1, 30, -0.1, 0.1, -1, 30);
Pre.addBC(diaphNodes, [1, 3], 0, 'Diaphragm');

% 4. Load: Gravity (Z-direction)
elemIDs = (1:size(Pre.Mesh.Elements, 1))';
% 'cartesian' type expects a handle returning the force vector
Pre.integrateSurfaceLoad(elemIDs, @() [0; 0; gravity], 'cartesian', 'Gravity');

% 5. Solver
Sol = FEM_Solver(Pre);
Sol.solveStatic();

% 6. Verification
% Target: Vertical displacement at midpoint of free edge (X=R*cos(phi_start), Y=25, Z=R*sin(phi_start))
testNode = Pre.selectNodesByBox(p_edge(1)-0.1, p_edge(1)+0.1, 24.9, 25.1, p_edge(3)-0.1, p_edge(3)+0.1);
w_calc = Sol.U((testNode(1)-1)*6 + 3);

fprintf('\n--- SCORDELIS-LO ROOF BENCHMARK ---\n');
fprintf('Mesh Size: %d elements\n', size(Pre.Mesh.Elements, 1));
fprintf('Calculated w: %.4f\n', abs(w_calc));
fprintf('Reference w:  0.3024\n');
fprintf('Error:        %.2f%%\n', abs(abs(w_calc)-0.3024)/0.3024*100);

if abs(abs(w_calc)-0.3024)/0.3024 < 0.05
    fprintf('[PASS] Within 5%% tolerance.\n');
else
    fprintf('[FAIL] Out of tolerance.\n');
end
