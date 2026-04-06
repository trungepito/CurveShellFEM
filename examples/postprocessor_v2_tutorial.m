%% POSTPROCESSOR_V2_TUTORIAL
% A comprehensive, step-by-step example for testing the refactored 
% FEM_Postprocessor_v2 in both linear and nonlinear analysis.
%
% This script serves as a verification benchmark and a user guide.
%
% Author: Verification Engineer
% Date: 2026-04-05

clear; clc; close all;
% setup_project;  % Ensure paths are set

%% ========================================================================
%  PART 1: LINEAR STATIC ANALYSIS
%  ========================================================================
fprintf('--- PART 1: LINEAR STATIC ANALYSIS ---\n');

% 1.1 Geometry & Material
E  = 210e9;   % Young's modulus (Pa)
nu = 0.3;     % Poisson's ratio
t  = 0.01;    % Thickness (m)
L  = 1.0;     % Length (m)
W  = 0.2;     % Width (m)

% 1.2 Preprocessor Setup
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createPlate([0, 0, 0], L, W);
Pre.meshAllPatches(10, 4);  % 10x4 mesh of Curve8 elements
Pre.computeNormals();

% 1.3 Boundary Conditions
% Fixed at X=0
fixedNodes = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixedNodes, 1:6, 0, 'Fixed_End');

% 1.4 Loading
% Uniform line load at X=L (downwards in Z)
tipNodes = Pre.selectNodesOnPlane(1, L, 1e-6);
P_total = -1000;  % Total load in Newtons
loadPerNode = P_total / length(tipNodes);
Pre.addNodalLoad(tipNodes, 3, loadPerNode, 'Tip_Load');

% 1.5 Solve (Linear Static)
Sol = FEM_Solver(Pre);
Sol.solveStatic();

% 1.6 Post-Processing Setup
% Initialize the refactored postprocessor (v2)
Post = FEM_Postprocessor_v2(Pre, Sol);

% 1.7 Field Visualization
% Global step index for static solve is 1
fprintf('Visualizing displacement field...\n');
Post.plotField('displacement_x', 1);
title('Linear: Z-Displacement (m)');
colorbar;

% Stress visualization using SPR (Superconvergent Patch Recovery)
fprintf('Visualizing von Mises stress field (SPR smoothed)...\n');
Post.plotField('von_mises', 1);
title('Linear: Von Mises Stress (Pa) - SPR Smoothed');
colorbar;

% 1.8 Error Estimation
% estimateErrorNorms returns an energy-based error indicator per element
fprintf('Estimating error norms...\n');
[errEl, totalNorm] = Post.estimateErrorNorms(1);
fprintf('Total global error norm: %.4e\n', totalNorm);
fprintf('Max element error indicator: %.4f\n\n', max(errEl));


%% ========================================================================
%  PART 2: NONLINEAR ELASTOPLASTIC ANALYSIS
%  ========================================================================
fprintf('--- PART 2: NONLINEAR ELASTOPLASTIC ANALYSIS ---\n');

% 2.1 Material Update: J2 Plasticity
sigY = 250e6;   % Yield Stress (Pa)
H_mod = 1e9;    % Hardening Modulus (Pa)
fprintf('Setting material to J2 Plasticity (sigY=%.1f MPa)...\n', sigY/1e6);
Pre.setMaterialPlastic(sigY, H_mod);

% 2.2 Increase Load to force yielding
P_total_nl = -3000; % Increased load (1 kN)
loadPerNode_nl = P_total_nl / length(tipNodes);
% Pre.clearLoads(); % This is not my logic, the logic here is that if the
% load is not activate than it is not there!
Pre.addNodalLoad(tipNodes, 3, loadPerNode_nl, 'NL_Load');
Pre.addBC(tipNodes,3, -0.35, 'TIP_disp');
% 2.3 Solver Setup (Adaptive Non-linear)
opts = SolverOptions();
opts.Tolerance      = 1e-4;
opts.InitialDt      = 1/100;  % 20 increments
opts.MaxIterations  = 15;
SolNL = FEM_Solver_Adaptive(Pre, opts);
% SolNL = FEM_Solver_ArcLength(Pre, opts);


% 2.4 Run Nonlinear Analysis
S1 = LoadingStage(1.0);
S1.activateBC('Fixed_End');
% S1.activateLoad('NL_Load');
S1.activateBC('TIP_disp');
% for arc length
% S1.ConstraintType  = 'Riks';
% S1.ArcLengthRadius = 0.02;  
% S1.ArcLengthPsi    = 1.0;  
% S1.ArcLengthMin    = 1e-4;
% S1.ArcLengthMax    = 0.1;
%
fprintf('Solving nonlinear stages...\n');
SolNL.solve({S1});

% 2.5 Re-initialize Postprocessor for NL Solver
PostNL = FEM_Postprocessor_v2(Pre, SolNL);

% 2.6 Post-Processing: Load-Displacement Curve
fprintf('Generating Load-Displacement curve...\n');
% Reaction at fixed end (DOF 3), Displacement at tip (DOF 3)
% Note: We pick the first tip node as the probe
probeNode = tipNodes(1);
PostNL.plotReactionDispCurve(SolNL.ReactionHist, probeNode, 3, 1);
title('Nonlinear: Load-Displacement at Tip');

% 2.7 Post-Processing: Yield Depth Evolution
% Plot yield penetration at the final step
lastStep = SolNL.StepCount;
fprintf('Plotting plastic yield depth at final step (%d)...\n', lastStep);
PostNL.plotField('yield_depth', lastStep);
title(sprintf('Plastic Yield Depth (%% of thickness) at Step %d', lastStep));
view(3);  % Isometric view

% 2.8 Future Performance Placeholder: History Animation
% prepare the code for later performance by including the API call (commented out)
fprintf('Tutorial: animateHistory(nodeID, dofIdx) can be used to animate evolution.\n');
PostNL.animateHistory(probeNode, 3); 


%% ========================================================================
%  CLEANUP & SUMMARY
%  ========================================================================
fprintf('\n--- TUTORIAL COMPLETE ---\n');
fprintf('Key Post-Processing capabilities demonstrated:\n');
fprintf('1. SPR-Smoothed nodal stress recovery\n');
fprintf('2. Energy-based error estimation\n');
fprintf('3. Multi-step Load-Displacement curve generation\n');
fprintf('4. Plastic yield depth visualization across thickness\n');
