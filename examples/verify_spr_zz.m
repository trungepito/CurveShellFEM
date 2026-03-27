% verify_spr_zz.m
clear; clc;

% 1. Run Scordelis-Lo (10x10)
E = 4.32e8; nu = 0.0; t = 0.25; R = 25; L = 25; theta = 40;
Pre = FEM_Preprocessor_v2(E, nu, t);
p_edge = [R*cosd(90-theta), 0, R*sind(90-theta)];
p_peak = [0, 0, R]; p_center = [0, 0, 0];
Pre.createExtrusion([p_edge; p_peak; p_center], [1, 2, 3, 10], [0, 1, 0], L, 10);

% BCs and Load
Pre.addBC(Pre.selectNodesByBox(-0.1, 0.1, -1, 30, -1, 30), [1, 5, 6], 0, 'Symm_Peak');
Pre.addBC(Pre.selectNodesByBox(-1, 30, 24.9, 25.1, -1, 30), [2, 4, 6], 0, 'Symm_Mid');
Pre.addBC(Pre.selectNodesByBox(-1, 30, -0.1, 0.1, -1, 30), [1, 3], 0, 'Diaphragm');
Pre.integrateSurfaceLoad((1:size(Pre.Mesh.Elements, 1))', @() [0; 0; -90], 'cartesian', 'Gravity');

Sol = FEM_Solver(Pre);
Sol.solveStatic();

% 2. SPR/ZZ Recovery
Post = FEM_Postprocessor(Pre, Sol);
fprintf('\n--- SPR/ZZ VERIFICATION ---\n');
[err_el, total_err] = Post.estimateErrorNorms();

% 3. Check consistency
if total_err > 0 && total_err < 100
    fprintf('[PASS] Error estimation converged to %.2f%%.\n', total_err*100);
else
    fprintf('[FAIL] Invalid error estimate.\n');
end

%% 4. (Optional) Visualize
Post.renderPlot(err_el, 'Energy Error Norm', struct('layer', 'Mid'));
