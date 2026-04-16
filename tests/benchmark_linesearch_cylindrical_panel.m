%% Comprehensive Line Search Benchmark: Cylindrical Panel GMNIA
% Compares convergence/performance of Standard vs Armijo vs No-LS on a snap-through problem.

fprintf('\n============================================================\n');
fprintf('  COMPREHENSIVE LINE SEARCH BENCHMARK: Cylindrical Panel\n');
fprintf('============================================================\n');

% -------------------------------------------------------------------------
% Path Setup
% -------------------------------------------------------------------------
scriptPath = fileparts(mfilename('fullpath'));
projectRoot = fullfile(scriptPath, '..');
addpath(fullfile(projectRoot, 'src'));
clear classes;

% -------------------------------------------------------------------------
% 1. Shared Geometry and Imperfection Pre-Analysis
% -------------------------------------------------------------------------
E  = 3102.75;
nu = 0.3;     
t  = 5.0; % Thinned for higher snap-through severity
R  = 2540;    
L  = 508;
angle = 0.1;

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createCylinderPanel(R, L, -angle, angle);
Pre.meshAllPatches(6, 6);
Pre.computeNormals();

% BCs (Hinged Edges)
tol = 1.0;
nodes_long = [Pre.selectNodesOnPlane(2, -angle*R, tol); Pre.selectNodesOnPlane(2, angle*R, tol)];
Pre.addBC(nodes_long, 1:3, 0, 'Hinged');

% Central Load Node
nodeCoords = Pre.Mesh.Nodes;
d2center = sum((nodeCoords - [R, 0, L/2]).^2, 2);
[~, centerID] = min(d2center);
Pre.addNodalLoad(centerID, 3, -1000.0, 'Central_P');

% PRE-ANALYSIS: Buckling for Imperfection
fprintf('[Setup] Running buckling analysis for imperfection...\n');
SolBuck = FEM_Solver(Pre);
SolBuck.solveStatic();
SolBuck.solveBuckling(1);
mode1 = SolBuck.ModeShapes(:, 1);
Pre.applyImperfection(mode1, t/10); 

% -------------------------------------------------------------------------
% Benchmark Controller
% -------------------------------------------------------------------------
configs = {
    'Reference_Riks', 'Riks',    false, 'standard'; % Ground truth
    'No_LineSearch',  'NR',      false, 'standard'; % Expected Fail
    'Standard_LS',    'NR',      true,  'standard';
    'Armijo_LS',      'NR',      true,  'armijo'
};

results = struct();

for i = 1:size(configs, 1)
    name = configs{i,1};
    type = configs{i,2};
    useLS = configs{i,3};
    lsMethod = configs{i,4};
    
    fprintf('\n--- CONFIG: %s (LS=%d, Method=%s) ---\n', name, useLS, lsMethod);
    
    opts = SolverOptions();
    opts.Tolerance = 1e-4;
    opts.UseLineSearch = useLS;
    opts.LineSearchMethod = lsMethod;
    
    Sol = FEM_Solver_Nonlinear(Pre, opts);
    
    stage = LoadingStage(1.0);
    stage.activateBC('Hinged');
    stage.activateLoad('Central_P');
    
    if strcmp(type, 'Riks')
        stage.ConstraintType = 'Riks';
        stage.ArcLengthRadius = 0.05;
    else
        % For NR runs, use large steps to challenge the solver
        stage.strategy = LoadControlStrategy('ArcLengthRadius', 0.2); 
        stage.strategy.ArcLengthMin = 0.2; % Force larger steps
    end
    
    tic;
    try
        Sol.solve({stage});
        results.(name).converged = true;
    catch ME
        fprintf(' [RUN FAILED: %s]\n', ME.message);
        results.(name).converged = false;
    end
    results.(name).time = toc;
    results.(name).steps = Sol.StepCount;
    results.(name).U_final = Sol.U;
    
    if results.(name).converged
        % Track the crown displacement path
        target_dof = (centerID-1)*6 + 3;
        results.(name).disp_path = Sol.U_Hist(target_dof, :);
        results.(name).load_path = Sol.LambdaHist;
    end
end

% -------------------------------------------------------------------------
% Analysis Summary
% -------------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf('  BENCHMARK SUMMARY\n');
fprintf('============================================================\n');
fn = fieldnames(results);
for k = 1:length(fn)
    res = results.(fn{k});
    if res.converged
        fprintf('%-15s: SUCCESS | Time: %6.2fs | Steps: %2d\n', fn{k}, res.time, res.steps);
    else
        fprintf('%-15s: FAILED  | Time: %6.2fs\n', fn{k}, res.time);
    end
end

% Accuracy Check against Reference
if results.Reference_Riks.converged && results.Armijo_LS.converged
    ref_u = max(abs(results.Reference_Riks.disp_path));
    arm_u = max(abs(results.Armijo_LS.disp_path));
    err = abs(ref_u - arm_u) / ref_u * 100;
    fprintf('\n[Accuracy] Armijo LS vs Reference Peak Disp Error: %.2f%%\n', err);
end

fprintf('\nBenchmark complete.\n');
