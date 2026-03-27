%% Diagnostic: Curved Element Stiffness Comparison
% Tests a single CURVED element (from the cylindrical mesh) to see
% whether ANS/EAS is stiffer or more flexible than baseline.

clear; clc; addpath(genpath('.'));

% Build a tiny 1-element mesh from the cylinder
Pre = FEM_Preprocessor_v2(3e6, 0.3, 3);
Pre.createCylinderPanel(300, 600, 0, pi/2);
Pre.meshAllPatches(2, 2);   % 2x2 mesh = 4 elements
Pre.computeNormals();

% Extract element 1 data
m = Pre.Mesh;
idx = m.Elements(1,:);
coords  = m.Nodes(idx,:);
normals = m.Normals(idx,:);

fprintf('=== Single Curved Element Stiffness Check ===\n');
fprintf('Coords range:  x[%.1f,%.1f]  y[%.1f,%.1f]  z[%.1f,%.1f]\n', ...
    min(coords(:,1)), max(coords(:,1)), ...
    min(coords(:,2)), max(coords(:,2)), ...
    min(coords(:,3)), max(coords(:,3)));

elB = Curve8Element(coords, normals, 3, 3e6, 0.3);
elA = Curve8Element_ANS_EAS(coords, normals, 3, 3e6, 0.3);

KeB = elB.computeStiffnessMatrix();
KeA = elA.computeStiffnessMatrix();

evB = sort(abs(eig(KeB)));
evA = sort(abs(eig(KeA)));

fprintf('\nBaseline  max eigenvalue: %.4e\n', evB(end));
fprintf('ANS/EAS   max eigenvalue: %.4e\n', evA(end));
fprintf('Baseline  sum(diag): %.4e\n', trace(KeB));
fprintf('ANS/EAS   sum(diag): %.4e\n', trace(KeA));

% Check: condensation difference
fprintf('\nStiffness ratio (trace): ANS/EAS / Baseline = %.4f\n', trace(KeA)/trace(KeB));
fprintf('(Expected: <1.0 means ANS/EAS is more flexible)\n');

% Apply a test unit bending mode and compare strain energy
% Apply u_z = 1 at the +x end nodes (simple bending)
u_test = zeros(40,1);
for n = 1:8
    if coords(n,3) > 450   % z near the top (z=600 end)
        u_test((n-1)*5 + 3) = 1.0;  % u_z = 1
    end
end
eA = 0.5 * u_test' * KeA * u_test;
eB = 0.5 * u_test' * KeB * u_test;
fprintf('\nBending strain energy (test load):\n');
fprintf('  Baseline: %.4e\n  ANS/EAS:  %.4e\n', eB, eA);
fprintf('  Ratio: %.4f  (< 1 = ANS/EAS softer in bending, correct)\n', eA/eB);
