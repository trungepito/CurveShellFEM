% audit_phase5_plastic_snapthrough.m
% AUDIT SCRIPT: Verifies the interaction between Arc-Length and Plasticity.
% Expected Result: FAIL (Currently results in purely elastic response due to state leak).

clear; clc; close all;

% 1. Setup Shallow Arc (Same as Phase 4/5 Benchmarks)
E = 200e9; nu = 0.3; t = 0.05; 
Pre = FEM_Preprocessor_v2(E, nu, t);
profile_nodes = [-5, 0, 0; 5, 0, 0; 0, 0, -1.34]; 
segs = [1, 2, 3, 12]; 
Pre.createExtrusion(profile_nodes, segs, [0, 1, 0], 5.0, 4);

% 2. Material: J2 Plasticity (Lower Yield for easier Audit)
sigY = 50e6; H_mod = 2e9; 
Pre.setMaterialPlastic(sigY, H_mod);

% 3. BCs: Pinned
leftNodes = Pre.selectNodesByBox(-5.1, -4.9, -1, 6, -5, 5);
rightNodes = Pre.selectNodesByBox(4.9, 5.1, -1, 6, -5, 5);
Pre.addBC([leftNodes; rightNodes], 1:3, 0, 'Pinned');

% 4. Load: Apply Pressure
elemIDs = (1:size(Pre.Mesh.Elements, 1))';
Pre.addPressureLoad(elemIDs, -20e6, 'Uniform'); % 20 MPa

% 5. Solver: New Arc-Length
Sol = FEM_Solver_ArcLength(Pre, SolverOptions());

% 6. Stage: Riks Control
S1 = LoadingStage(0.5); % Reach 10 MPa at lambda=0.5
S1.activateBC('Pinned');
S1.activateLoad('Uniform'); 
S1.ConstraintType  = 'Riks';
S1.ArcLengthRadius = 0.05;  
S1.ArcLengthPsi    = 0.0;  
S1.ArcLengthMin    = 1e-4;
S1.ArcLengthMax    = 0.1;

fprintf('\n--- AUDIT: RUNNING PLASTIC SNAP-THROUGH (ARCLENGTH) ---\n');
Sol.solve({S1});

if Sol.StepCount > 0
    fprintf('Analysis finished, but was it PLASTIC?\n');
    % Verification step: check if any element has non-zero plastic strain history
    max_p = 0;
    for e = 1:length(Sol.Elements)
        if isa(Sol.Elements{e}, 'Curve8Element_Plastic')
            p_vals = [Sol.Elements{e}.HistoryData.p];
            max_p = max(max_p, max(p_vals));
        end
    end
    
    fprintf('Max Effective Plastic Strain (p): %.4e\n', max_p);
    
    if max_p > 1e-9
        fprintf('[PASS] Plasticity detected in element histories.\n');
    else
        fprintf('[FAIL] Elements are ELASTIC. Converged history was NOT committed.\n');
    end
end
