function result = verify_scordelis_lo_roof()
% VERIFY_SCORDELIS_LO_ROOF  NAFEMS barrel vault benchmark.
%
% VT3.1  Quarter model: 0 <= phi <= 40 deg, 0 <= z <= L/2, 4x4 mesh.
% VT3.2  Self-weight body force (gravity in -Z).
% VT3.3  Reference: u_z at free-edge midpoint = -0.3024.
% VT3.4  PASS: |u_z_FEM - u_z_ref| / |u_z_ref| < 0.02 (2% tolerance).
%
% NAFEMS benchmark (Scordelis & Lo 1964, MacNeal & Harder 1985):
%   R=25, L=50, t=0.25, phi_0=40 deg, E=4.32e8, nu=0.
%   Self-weight q=90 per unit area.  Reference u_z(free edge mid)=-0.3024.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('verify_scordelis_lo_roof');

result = run_subtest(result, 'VT3.1-VT3.4 Scordelis-Lo free-edge midpoint within 2%', ...
    @() run_scordelis_lo());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_scordelis_lo()
R      = 25.0;
L      = 50.0;
t      = 0.25;
phi0   = 40 * pi / 180;   % 40 degrees in radians
E      = 4.32e8;
nu     = 0.0;
q_grav = 90.0;
u_z_ref = -0.3024;

fprintf('  [Scordelis-Lo] Reference u_z (free edge mid) = %.4f\n', u_z_ref);

% ----------------------------------------------------------------
% VT3.1  Quarter model: createCylinderPanel(R, H, angleStart, angleEnd)
% Maps: x = R*cos(angle), y = R*sin(angle), z in [0, H].
% Quarter model: angle in [0, phi0], z in [0, L/2].
%   angle=0     -> x=R,               y=0        (phi=0 symmetry plane)
%   angle=phi0  -> x=R*cos(phi0)=19.15, y=R*sin(phi0)=16.07 (free edge)
% ----------------------------------------------------------------
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createCylinderPanel(R, L/2, 0, phi0);
Pre.meshAllPatches(4, 4);

nNodes = size(Pre.Mesh.Nodes, 1);
nodes  = Pre.Mesh.Nodes;

% ----------------------------------------------------------------
% Boundary conditions
% ----------------------------------------------------------------
% Diaphragm at z=0 (curved end): Ux=0, Uz=0
z0_nodes = Pre.selectNodesOnPlane(3, 0.0,  1e-3);
Pre.addBC(z0_nodes, [1, 3], 0, 'Diaphragm0');

% Diaphragm at z=L/2 (other curved end): Ux=0, Uz=0
zL_nodes = Pre.selectNodesOnPlane(3, L/2,  1e-3);
Pre.addBC(zL_nodes, [1, 3], 0, 'DiaphragmL');

% Symmetry at phi=0 (y=0 plane, angle=0): Uy=0, Rx=0
% createCylinderPanel at angle=0 places nodes at y=0.
y0_nodes = Pre.selectNodesOnPlane(2, 0.0, 1e-3);
Pre.addBC(y0_nodes, [2, 4], 0, 'SymPhi');

% Symmetry at z=L/2: Uz=0 (already set by DiaphragmL DOF 3), Ry=0
Pre.addBC(zL_nodes, 5, 0, 'SymZ');

% ----------------------------------------------------------------
% VT3.2  Self-weight as distributed load
% ----------------------------------------------------------------
all_elems = (1 : size(Pre.Mesh.Elements, 1))';
Pre.addDistributedLoad(all_elems, [0; 0; -q_grav], 'Gravity');

Sol = FEM_Solver(Pre);
Sol.solveStaticDisplacement();

% ----------------------------------------------------------------
% VT3.3/VT3.4  Free-edge midpoint: phi=phi0, z=0
% createCylinderPanel: x=R*cos(angle), y=R*sin(angle)
% At phi=phi0 (free edge):  x=R*cos(phi0), y=R*sin(phi0), z=0
% ----------------------------------------------------------------
x_free = R * cos(phi0);   % 19.15  (NOT sin)
y_free = R * sin(phi0);   % 16.07  (NOT cos)
z_free = 0.0;

% Generous tolerance for node search (mesh spacing ~ L/2 / 4 ~ 3.1)
tol_node = 2.0;
free_mid_nodes = Pre.selectNodesByBox( ...
    x_free - tol_node, x_free + tol_node, ...
    y_free - tol_node, y_free + tol_node, ...
    z_free - tol_node, z_free + tol_node);

if isempty(free_mid_nodes)
    % Fallback: find the globally closest node to the target point
    dists_all = sqrt((nodes(:,1) - x_free).^2 + ...
                     (nodes(:,2) - y_free).^2 + ...
                     (nodes(:,3) - z_free).^2);
    [min_dist, ref_node] = min(dists_all);
    fprintf('  [Scordelis-Lo] Fallback node search: node %d at dist=%.3f\n', ...
        ref_node, min_dist);
else
    dists = sqrt((nodes(free_mid_nodes,1) - x_free).^2 + ...
                 (nodes(free_mid_nodes,2) - y_free).^2 + ...
                 (nodes(free_mid_nodes,3) - z_free).^2);
    [~, ii] = min(dists);
    ref_node = free_mid_nodes(ii);
end

uz_dof  = (ref_node - 1) * 6 + 3;
u_z_FEM = Sol.U(uz_dof);

rel_err = abs(u_z_FEM - u_z_ref) / abs(u_z_ref);
fprintf('  [Scordelis-Lo] Node %d at (%.2f, %.2f, %.2f)\n', ...
    ref_node, nodes(ref_node,1), nodes(ref_node,2), nodes(ref_node,3));
fprintf('  [Scordelis-Lo] FEM u_z = %.4f,  ref = %.4f,  err = %.2f%%\n', ...
    u_z_FEM, u_z_ref, rel_err*100);

if rel_err > 0.02
    error('SCORDELIS-LO FAILED: u_z_FEM=%g, u_z_ref=%g, error=%.2f%% > 2%%', ...
          u_z_FEM, u_z_ref, rel_err*100);
end
end
