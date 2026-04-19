-----------------------------------------------------------------
 PASSED:  4 / 18
 SKIPPED: 5 (filter: fast)
 FAILED:  14
----
Failed tests:

###  [1] test_material_j2plastic
      3/5 subtests passed
        [PASS] UT4.1 elastic response below yield
        [PASS] UT4.2 stress on yield surface after return
        [FAIL] UT4.3 tangent consistency (FD) — Tangent column 1: FD vs analytic relative error = 0.0117627 > 1e-05
        [FAIL] UT4.4 plastic incompressibility — Plastic flow direction inconsistent: deps_py/deps_px = -0.442634 (expected ≈ -0.5)
        [PASS] UT4.5 Newton loop converges for 50 random strains

###  [2] test_solution_state
      4/5 subtests passed
        [PASS] UT5.1 all-mode StepCount and U_Hist size
        [FAIL] UT5.2 rolling mode memory and eviction — Rolling buffer has 35 columns, expected 5 (RollingWindow)
        [PASS] UT5.3 snapshot is independent copy
        [PASS] UT5.4 beginStage increments StageCount
        [PASS] UT5.5 setEigenResults / snapshot.ModeShapes

 ###  [3] test_incremental_strategies
      4/5 subtests passed
        [PASS] UT6.1 Riks predictor tangent solve
        [PASS] UT6.2 Riks constraint zero at predictor
        [PASS] UT6.3 LoadControl constraint formula
        [FAIL] UT6.4 DispControl constraint after initialize — ControlDOF_local=0 out of range for u_f(length=4).
        [PASS] UT6.5 adaptRadius grows and shrinks correctly

  ###  [4] test_data_manager
      3/5 subtests passed
        [PASS] UT7.1 initProject creates meta JSON
        [PASS] UT7.2 writeStep_ O(1) scaling
        [PASS] UT7.3 loadSingleStep_ returns correct U
        [FAIL] UT7.4 restartFromCheckpoint StepCount — In class 'FEM_Solver_Nonlinear', no set method is defined for dependent property 'LambdaHist'. A dependent property needs a set method to assign its value.
        [FAIL] UT7.5 delete invalidates listeners — No public property 'Listeners_' for class 'FEM_DataManager'.

  ### [5] test_solver_options
      4/5 subtests passed
        [PASS] UT8.1 default values correct
        [PASS] UT8.2 validate passes on defaults
        [PASS] UT8.3 validate throws MaxIterations < 3
        [PASS] UT8.4 validate throws bad NormType
        [FAIL] UT8.5 validate throws MinDt >= MaxDt — validate() did not throw for MinDt == MaxDt

  ### [6] test_elastic_plate_linear
      1/4 subtests passed
        [FAIL] IT1.1 max deflection within 5% of analytical — Max deflection = 0.000283641 m, analytical = 8.5995e-06 m, rel error = 3198.35% > 5%
        [PASS] IT1.2 BucklingFactors empty before buckling solve
        [FAIL] IT1.3 solveBuckling(3) returns 3 positive factors — Unable to find a valid starting vector. Most likely the matrix B has low rank.
        [FAIL] IT1.4 postprocessor von_mises field size — Unrecognized method, property, or field 'state' for class 'FEM_Solver'.

  ### [7] test_elastic_plate_nonlinear
      0/4 subtests passed
        [FAIL] IT2.1 StepCount == 5 — StepCount: expected |a-b| <= 0, got 1
        [FAIL] IT2.2 U_Hist size and Uz monotone — U_Hist has 4 columns, expected 5
        [FAIL] IT2.3 state.StepCount == 5 — state.StepCount: expected |a-b| <= 0, got 1
        [FAIL] IT2.4 displacement_z field matches Sol.U — Requested step 5 but only 4 steps are in the snapshot.

  ### [8] test_plastic_plate
      1/5 subtests passed
        [FAIL] IT3.1 StepCount == 10 — StepCount: expected |a-b| <= 0, got 8
        [FAIL] IT3.2 some GP yielded at step 10 — No GP has p > 0 at step 10 — yielding did not occur
        [FAIL] IT3.3 PlasticHistoryArchive{10} non-empty — PlasticHistoryArchive{10} is empty
        [FAIL] IT3.4 recoverField p at step 10 > 0 — Requested step 10 but only 2 steps are in the snapshot.
        [PASS] IT3.5 plastic strain monotone across steps

  [9] test_cylindrical_panel_snapthrough
      2/4 subtests passed
        [FAIL] IT4.1 StepCount == 20 — StepCount: expected |a-b| <= 0, got 20
        [FAIL] IT4.2 LambdaHist shows load reversal — LambdaHist is monotonically increasing — snap-through not detected. min(diff) = 
        [PASS] IT4.3 Crown displacement monotone increasing
        [PASS] IT4.4 all steps converged

  ### [10] test_buckling_eigenvalue
      1/3 subtests passed
        [FAIL] IT5.1 lambda_1 within 5% of Ncr_analytical — lambda_1 = 6.84553e-08 → Ncr_FEM = 6.84553e-08 N/m, analytical = 180762 N/m, error = 100.00% > 5%
        [PASS] IT5.2 ModeShapes size [nDofs x 3]
        [FAIL] IT5.3 mode shapes max-normalised — Mode 1: max(|phi|) = 0.146059, expected 1.0 (not max-normalised)

  ### [11] test_data_manager_pipeline
      1/4 subtests passed
        [PASS] IT6.1 project status is complete
        [FAIL] IT6.2 restartFromCheckpoint StepCount — In class 'FEM_Solver_Nonlinear', no set method is defined for dependent property 'LambdaHist'. A dependent property needs a set method to assign its value.
        [FAIL] IT6.3 loadStageHistory dimensions — U_hist has 5 columns, expected nStepsTarget=10
        [FAIL] IT6.4 listRestartPoints reports nSteps — Stage 1 nSteps = 5, expected 10

  ### [12] verify_patch_test
      0/1 subtests passed
        [FAIL] VT1.1-VT1.3 patch test sigma_x error < 1e-8 — Unrecognized method, property, or field 'state' for class 'FEM_Solver'.

  ### [13] verify_scordelis_lo_roof
      0/1 subtests passed
        [FAIL] VT3.1-VT3.4 Scordelis-Lo free-edge midpoint within 2% — Could not find node at free-edge midpoint (16.07, 19.15, 0.00)

  ### [14] verify_replay_determinism
      0/1 subtests passed
        [FAIL] VT6.1-VT6.5 snapshot replay determinism — Expected 15 converged steps, got 0
