%% Profiler Wrapper for GMNIA
clear; clc; addpath(genpath('.'));

fprintf('Starting Profiler on GMNIA Benchmark...\n');
profile on;

E  = 3102.75; 
nu = 0.3;     
t  = 12.7;    
R  = 2540;    
L  = 508;
angle = 0.1;

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createCylinderPanel(R, L, -angle, angle);
Pre.meshAllPatches(4, 4); % 16 elements, fast mesh
Pre.computeNormals();

tol = 1.0;
nodes_long = [Pre.selectNodesOnPlane(2, -angle*R, tol); Pre.selectNodesOnPlane(2, angle*R, tol)];
Pre.addBC(nodes_long, 1, 0, 'Hinged_UX');
Pre.addBC(nodes_long, 2, 0, 'Hinged_UY');
Pre.addBC(nodes_long, 3, 0, 'Hinged_UZ');

nodeCoords = Pre.Mesh.Nodes;
d2center = sum((nodeCoords - [R, 0, L/2]).^2, 2);
[~, centerID] = min(d2center);
Pre.addNodalLoad(centerID, 3, -1.0, 'Central_P');

% Plastic Material
Pre.setMaterialPlastic(50.0, 100.0);

opts = SolverOptions();
opts.Tolerance = 1e-3;
Sol = FEM_Solver_ArcLength(Pre, opts);

% Solve to just load factor 20 (instead of 500) to keep profile fast (~2-3 steps)
S1 = LoadingStage(20.0);
S1.activateBC('Hinged_UX');
S1.activateBC('Hinged_UY');
S1.activateBC('Hinged_UZ');
S1.activateLoad('Central_P');
S1.ConstraintType = 'Riks';
S1.ArcLengthRadius = 10.0;

Sol.solve({S1});

profile off;
fprintf('Profiling finished. Extracting top 15 functions...\n');
p = profile('info');
[~, sortIdx] = sort([p.FunctionTable.TotalTime], 'descend');

fprintf('\n==== TOP 15 PROFLED FUNCTIONS ====\n');
fprintf('Total Profiling Time: %.3f s\n', p.FunctionTable(sortIdx(1)).TotalTime);
fprintf('%-50s : %8s : %s\n', 'FUNCTION', 'TIME (s)', 'CALLS');
for i = 1:min(15, length(sortIdx))
    idx = sortIdx(i);
    funcName = p.FunctionTable(idx).FunctionName;
    totalTime = p.FunctionTable(idx).TotalTime;
    calls = p.FunctionTable(idx).NumCalls;
    fprintf('%-50s : %8.3f : %5d\n', funcName, totalTime, calls);
end
fprintf('===================================\n');
disp('Done.');
