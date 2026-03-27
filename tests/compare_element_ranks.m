%% Rank Comparison: Baseline vs ANS/EAS
clear; clc; addpath(genpath('.'));

coords = [0,0,0; 1,0,0; 1,1,0; 0,1,0; 0.5,0,0; 1,0.5,0; 0.5,1,0; 0,0.5,0];
normals = repmat([0,0,1], 8, 1);
t = 0.1; E = 210e9; nu = 0.3;

fprintf('--- Baseline Element (Curve8Element) ---\n');
elB = Curve8Element(coords, normals, t, E, nu);
KeB = elB.computeStiffnessMatrix();
evB = sort(abs(eig(KeB)));
nZeroB = sum(evB < 1e-3 * max(evB));
fprintf('Number of Zero Eigenvalues: %d\n', nZeroB);

fprintf('\n--- Augmented Element (Curve8Element_ANS_EAS) ---\n');
elA = Curve8Element_ANS_EAS(coords, normals, t, E, nu);
KeA = elA.computeStiffnessMatrix();
evA = sort(abs(eig(KeA)));
nZeroA = sum(evA < 1e-3 * max(evA));
fprintf('Number of Zero Eigenvalues: %d\n', nZeroA);

if nZeroA > nZeroB
    fprintf('\nWARNING: Mitigation introduced %d extra zero modes.\n', nZeroA - nZeroB);
end
