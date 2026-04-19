function result = verify_patch_test()
% VERIFY_PATCH_TEST  MacNeal-Harder patch test for 8-node shell element.
%
% VT1.1  Build a 2x2 mesh of distorted elements.
% VT1.2  Apply linear displacement BCs consistent with sigma_x = 1 Pa (constant).
% VT1.3  PASS: max|sigma_x - 1| < 1e-8 at all nodes (machine precision).
%
% The patch test verifies that the element can represent a constant stress
% state exactly on an irregular mesh. This is the fundamental completeness
% check for any finite element formulation.
%
% Constant stress state used:
%   u = sigma_x / E * x       (uniaxial tension in x)
%   v = -nu * sigma_x / E * y
%   w = -nu * sigma_x / E * z = 0 (mid-plane, z=0)
% => sigma_x = 1 Pa, all other stresses = 0.

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('verify_patch_test');

E  = 1.0;   % unit modulus simplifies checking
nu = 0.25;
t  = 0.1;
sigma_x_ref = 1.0;   % Pa

% ----------------------------------------------------------------
% VT1.1  Build 2x2 mesh with distorted interior node positions.
% Outer boundary nodes are placed on a unit square.
% Interior nodes are perturbed from the regular grid position.
% ----------------------------------------------------------------
result = run_subtest(result, 'VT1.1-VT1.3 patch test sigma_x error < 1e-8', ...
    @() run_patch_test(E, nu, t, sigma_x_ref));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_patch_test(E, nu, t, sigma_x_ref)
% Build the mesh manually to control node positions precisely.
Pre = FEM_Preprocessor_v2(E, nu, t);

% Create a 1x1 plate with slight mesh distortion
Pre.createPlate([0, 0, 0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);   % 2x2 = 4 elements

% Distort one interior node to create an irregular mesh.
% Find the interior node at approximately (0.5, 0.5, 0).
nodes = Pre.Mesh.Nodes;
[~, int_idx] = min(abs(nodes(:,1) - 0.5) + abs(nodes(:,2) - 0.5));
Pre.Mesh.Nodes(int_idx, 1) = 0.52;   % slight x perturbation
Pre.Mesh.Nodes(int_idx, 2) = 0.48;   % slight y perturbation
Pre.computeNormals();   % recompute after distortion

nNodes = size(Pre.Mesh.Nodes, 1);

% ----------------------------------------------------------------
% VT1.2  Apply linear displacement BCs for sigma_x = 1 Pa state.
% ----------------------------------------------------------------
% Displacement field for plane-stress uniaxial tension:
%   u(x,y) = (sigma_x / E) * x
%   v(x,y) = -(nu * sigma_x / E) * y
%   w = 0  (thin plate, no out-of-plane loading)
%   rotations = 0 (no bending)

eps_x  = sigma_x_ref / E;
eps_y  = -nu * eps_x;

% Apply prescribed displacements on ALL nodes (essential BCs)
for n = 1:nNodes
    x = Pre.Mesh.Nodes(n, 1);
    y = Pre.Mesh.Nodes(n, 2);

    u_prescribed = eps_x * x;
    v_prescribed = eps_y * y;
    w_prescribed = 0;

    Pre.addBC(n, 1, u_prescribed, 'PatchBC');   % Ux
    Pre.addBC(n, 2, v_prescribed, 'PatchBC');   % Uy
    Pre.addBC(n, 3, w_prescribed, 'PatchBC');   % Uz
    Pre.addBC(n, 4, 0,            'PatchBC');   % Rx
    Pre.addBC(n, 5, 0,            'PatchBC');   % Ry
    Pre.addBC(n, 6, 0,            'PatchBC');   % Rz (drilling)
end

Sol = FEM_Solver(Pre);
Sol.solveStaticDisplacement();

% ----------------------------------------------------------------
% VT1.3  Recover sigma_x and check error < 1e-8.
% ----------------------------------------------------------------
Post    = FEM_Postprocessor_v2(Pre, Sol);
sigma_x = Post.recoverField('sigma_x', 1);

max_err = max(abs(sigma_x - sigma_x_ref));
tol     = 1e-8;

fprintf('  [Patch Test] max|sigma_x - %.1f| = %.3e  (tol %.0e)\n', ...
    sigma_x_ref, max_err, tol);

if max_err > tol
    error(['PATCH TEST FAILED: max|sigma_x - %g| = %g > %g.\n' ...
           'The element does not pass the completeness (patch) test.\n' ...
           'Check shape function completeness and B-matrix assembly.'], ...
          sigma_x_ref, max_err, tol);
end
end
