# CurveShellFEM v3 — Solver Hardening & Test Suite Implementation Plan

**For AI agent execution. Every task has a precise definition of done.
Implementation is complete only when all verification gates pass.**

---

## Document conventions

- `[ ]` unchecked box = task not started
- `[x]` checked box = task complete and verified
- **P0** = must complete before any other wave starts
- **P1** = must complete before Wave 3 starts
- **P2** = must complete before the final verification gate
- File paths are relative to the repository root (`src/`, `tests/`, etc.)
- All new source files live under `src/`; all new test files live under `tests/`
- No legacy aliases, no backward-compatibility shims, no references to deprecated classes are permitted in any new file

---

## Repository target structure

```
CurveShellFEM/
├── src/
│   ├── @Assembler/
│   ├── @ConvergenceMonitor/
│   ├── @Curve8Element/
│   ├── @Curve8Element_ANS_EAS/
│   ├── @DispControlStrategy/
│   ├── @FEM_DataManager/
│   ├── @FEM_Postprocessor_v2/
│   ├── @FEM_Preprocessor_v2/
│   ├── @FEM_Solver/
│   ├── @FEM_Solver_Nonlinear/       ← sole nonlinear entry point
│   ├── @IncrementalStrategy/
│   ├── @LoadControlStrategy/
│   ├── @LoadingStage/
│   ├── @Material_J2Plastic/
│   ├── @MathFEM/
│   ├── @RiksStrategy/
│   ├── @SolutionSnapshot/
│   ├── @SolutionState/
│   ├── @SolverEventData/
│   └── @SolverOptions/
├── tests/
│   ├── unit/
│   │   ├── test_assembler.m
│   │   ├── test_convergence_monitor.m
│   │   ├── test_curve8element.m
│   │   ├── test_data_manager.m
│   │   ├── test_incremental_strategies.m
│   │   ├── test_material_j2plastic.m
│   │   ├── test_solution_state.m
│   │   └── test_solver_options.m
│   ├── integration/
│   │   ├── test_elastic_plate_linear.m
│   │   ├── test_elastic_plate_nonlinear.m
│   │   ├── test_plastic_plate.m
│   │   ├── test_cylindrical_panel_snapthrough.m
│   │   ├── test_buckling_eigenvalue.m
│   │   └── test_data_manager_pipeline.m
│   ├── verification/
│   │   ├── verify_patch_test.m
│   │   ├── verify_beam_bending.m
│   │   ├── verify_scordelis_lo_roof.m
│   │   ├── verify_cylindrical_panel_riks.m
│   │   ├── verify_plastic_thick_plate.m
│   │   └── verify_replay_determinism.m
│   ├── benchmarks/
│   │   ├── bench_assembly_scaling.m
│   │   ├── bench_solver_convergence.m
│   │   └── bench_datamanager_io.m
│   └── run_all_tests.m
└── IMPLEMENTATION_PLAN.md           ← this file
```

---

## Wave 0 — Repository cleanup (prerequisite, no code changes)

Complete these before writing a single line of new code.

- [ ] **W0.1** Delete the following files entirely. They must not exist in the repository after this step:
  - `src/@FEM_Solver_ArcLength/` (entire directory)
  - `src/@FEM_Solver_Adaptive/` (entire directory)
  - `src/@FEM_Preprocessor/` (entire directory — legacy v1)
  - `src/@FEM_Preprocessor_CAD/` (entire directory — superseded by v2)
  - `src/@FEM_Postprocessor/` (entire directory — legacy v1)
  - `src/@GeometryEngine/` (entire directory — methods duplicated in v2)
  - `src/@SolverLinearEventData/` (superseded by `SolverEventData`)
  - `src/FEM_Postprocessor_App.m` (standalone app file, not part of core)
  - Any file named `*.m` in `tests/` that is not in the new structure above
  - Any file named `benchmark_*.m` or `test_*.m` in `examples/` or root

- [ ] **W0.2** Verify no remaining source file contains `FEM_Solver_ArcLength`, `FEM_Solver_Adaptive`, `FEM_Postprocessor`, `FEM_Preprocessor_CAD`, or `GeometryEngine` as a class name reference. Use `grep -r` across `src/` and `tests/`. Result must be zero matches.

- [ ] **W0.3** Verify no remaining source file inherits from a deleted class. Search for `< FEM_Solver_ArcLength`, `< FEM_Solver_Adaptive`, `< FEM_Postprocessor`. Zero matches required.

- [ ] **W0.4** Run `matlab -batch "addpath(genpath('src')); disp('paths ok')"` and confirm no path errors.

**Gate W0:** All four items checked, zero grep matches, paths load cleanly.

---

## Wave 1 — P0 correctness bugs (must complete before any testing)

Each bug fix has an exact file target, a precise change description, and a local verification step.

### Bug 1 — Residual sign inversion

**Files:** `src/@FEM_Solver_Nonlinear/linesearch.m`, `src/@FEM_Solver_Nonlinear/armijoSearch.m`

- [ ] **1.1** In `linesearch.m`, change line:
  ```matlab
  % BEFORE (wrong sign)
  R_trial = F_ext_current - F_int_trial;
  % AFTER (correct)
  R_trial = F_int_trial - F_ext_current;
  ```
  Also change the acceptance metric from `R_norm_new < R_norm_old` to use the signed dot-product guard:
  ```matlab
  s_trial = dot(R_trial(free_dofs), dU(free_dofs));
  if R_norm_new < R_norm_old || abs(s_trial) <= controlf * abs(s0)
  ```

- [ ] **1.2** In `armijoSearch.m`, audit every use of `R_try`. Confirm the residual is computed as `F_int - F_ext` throughout. No instance of `F_ext - F_int` may remain. The Armijo condition must read:
  ```matlab
  r_try = norm(R_try(free_dofs));
  if r_try <= (1.0 - c1 * alpha) * r0
  ```
  where `R_try = F_int_try - F_ext` (not subtracted in reverse).

- [ ] **1.3** In `newtonLoop.m`, confirm the residual definition at line ~49 reads `R = F_int - F_ext` and add an inline comment `% Convention: R = F_int - lambda*F_ext; positive when over-loaded`.

- [ ] **1.4** Local verification: write a 1-element single-step test. Assert that `dot(R_newtonLoop, R_linesearch) > 0` (same direction). Add as `tests/unit/test_residual_sign.m`.

**Gate 1:** `test_residual_sign.m` passes.

---

### Bug 2 — Function name shadow in `solveIncrementalStage`

**File:** `src/@FEM_Solver_Nonlinear/solveIncrementalStage.m`

- [ ] **2.1** Locate the local function at the bottom of `solveIncrementalStage.m` named `assembleForArcLength` (approximately lines 288–300). Delete it entirely.

- [ ] **2.2** Rename the closure defined at the top of the main function body from `assembleForArcLength` to `assembleFn`. Update all three call sites inside the while-loop body to use `assembleFn`.

- [ ] **2.3** Verify the closure captures `F_ext_total` (the stage-local variable), not `obj.F_ext_start`. Search the closure body for `F_ext_start`; result must be zero occurrences.

- [ ] **2.4** Local verification: run a two-stage analysis where Stage 2 has a different load magnitude than Stage 1. Assert that `Sol.LambdaHist` is monotonically consistent with the stage durations, not drifting back to zero.

**Gate 2:** Two-stage lambda drift test passes.

---

### Bug 3 — Double plastic history commit

**Files:** `src/@FEM_Solver_Nonlinear/newtonLoop.m`, `src/@FEM_Solver_Nonlinear/solveIncrementalStage.m`

- [ ] **3.1** Modify `newtonLoop.m` to **not** call `commitHistory` internally. Instead, return `TrialHist` as a fourth output argument:
  ```matlab
  function [converged, U_out, reaction, TrialHist] = newtonLoop(obj, F_ext, U_curr, fixed_dofs)
  ```
  Remove the `obj.commitHistory(TrialHist)` call from inside the function. The converged branch now simply sets `U_out = U_curr` without committing.

- [ ] **3.2** In `solveIncrementalStage.m`, after the corrector loop confirms convergence, perform exactly one commit-and-snapshot sequence in this order:
  ```matlab
  % 1. Capture TrialHist BEFORE commit (for archival)
  plasticSnap = TrialHist_conv;   % cell array from corrector
  % 2. Commit exactly once
  obj.commitHistory(TrialHist_conv);
  % 3. Archive the pre-commit snapshot
  obj.state.appendStep(u_converged, lambda, plasticSnap, reaction_struct, trial_ds);
  ```
  There must be no other call to `commitHistory` in this file.

- [ ] **3.3** Search `src/@FEM_Solver_Adaptive/` — this directory has been deleted in W0.1 so there should be no remaining `solveStage.m`. Confirm zero results for `commitHistory` outside the two files above.

- [ ] **3.4** Local verification: run a 5-step plastic analysis. At each step, verify that `Sol.state.PlasticHistoryArchive{k}` was captured before `Elements{e}.HistoryData` reflects that step's commit. Check by comparing the equivalent plastic strain at step `k` in the archive against direct element query — they must match exactly (to machine precision).

**Gate 3:** Plastic archive consistency test passes.

---

### Bug 4 — SolutionState dual write paths

**Files:** `src/@FEM_Solver_Nonlinear/FEM_Solver_Nonlinear.m`, `src/@FEM_Solver_Nonlinear/solveIncrementalStage.m`

- [ ] **4.1** In `FEM_Solver_Nonlinear.m`, remove `U_Hist`, `History_Time`, `ArcLengthHistory`, `ReactionHist`, and `StepCount` as stored properties. They must only exist as dependent properties delegating to `obj.state`. The class definition after this change must not contain any `U_Hist = []` or similar initializations in `properties` blocks.

- [ ] **4.2** Remove all direct field-write statements of the form `obj.U_Hist(:, obj.StepCount) = ...` and `obj.History_Time(obj.StepCount) = ...` and `obj.StepCount = obj.StepCount + 1` from `solveIncrementalStage.m`. These operations must only happen through `obj.state.appendStep(...)`.

- [ ] **4.3** Verify that the dependent property getters correctly slice `obj.state`:
  ```matlab
  function v = get.U_Hist(obj)
      v = obj.state.U_Hist(:, 1:obj.state.StepCount);
  end
  function v = get.StepCount(obj)
      v = obj.state.StepCount;
  end
  ```
  These must be the only definitions of these properties.

- [ ] **4.4** Local verification: run a 10-step elastic analysis. Assert `size(Sol.U_Hist, 2) == Sol.StepCount == 10`. Assert `Sol.state.StepCount == 10`. Assert `isequal(Sol.U_Hist, Sol.state.U_Hist(:, 1:10))`.

**Gate 4:** State consistency test passes.

---

### Bug 5 — ConvergenceMonitor receives empty `dU`

**File:** `src/@FEM_Solver_Nonlinear/solveIncrementalStage.m`

- [ ] **5.1** Before the corrector loop begins, initialize `u_prev = u_pred` (the predicted state).

- [ ] **5.2** Inside the corrector loop, at the point where `mon.check(...)` is called, replace the `[]` argument:
  ```matlab
  % BEFORE
  if mon.check(R_f, [], u_trial(free_dofs), fext_f, i)
  % AFTER
  dU_free = u_trial(free_dofs) - u_prev(free_dofs);
  if mon.check(R_f, dU_free, u_trial(free_dofs), fext_f, i)
  ```

- [ ] **5.3** After the check, update `u_prev = u_trial`.

- [ ] **5.4** In `SolverOptions.m`, set the default `NormType = 'force'` (already correct). Add a validation block that rejects unknown norm types with a clear error message.

- [ ] **5.5** Local verification: configure `opts.NormType = 'energy'` and run a 3-step nonlinear analysis. Assert that `mon.ResidualHistory` is non-zero at iteration 1 (proving the energy norm is actually computed, not trivially zero from an empty `dU`).

**Gate 5:** Energy-norm activation test passes.

---

### Bug 6 — SolutionState rolling mode memory leak

**File:** `src/@SolutionState/SolutionState.m`

- [ ] **6.1** Replace the `growArrays` method and the eviction logic with a circular buffer implementation:
  ```matlab
  % In constructor, when MemoryMode == 'rolling':
  obj.U_Hist = zeros(obj.nDofs, obj.RollingWindow);
  obj.LambdaHist = zeros(1, obj.RollingWindow);
  obj.ArcLengthHist = zeros(1, obj.RollingWindow);
  % Write pointer:
  obj.WritePtr = 0;  % new private property
  ```

- [ ] **6.2** In `appendStep`, compute the ring slot:
  ```matlab
  if strcmp(obj.MemoryMode, 'rolling')
      slot = mod(obj.StepCount, obj.RollingWindow) + 1;
  else
      slot = obj.StepCount;
      if slot > obj.Capacity, obj.growArrays(); end
  end
  obj.U_Hist(:, slot) = U;
  ```

- [ ] **6.3** Implement `getU(globalStep)` to map global step index to the ring slot, raising an error if the step has been evicted:
  ```matlab
  function U = getU(obj, stepIdx)
      if strcmp(obj.MemoryMode, 'rolling')
          oldest = max(1, obj.StepCount - obj.RollingWindow + 1);
          if stepIdx < oldest
              error('SolutionState:evicted', 'Step %d has been evicted (window=%d)', ...
                    stepIdx, obj.RollingWindow);
          end
          slot = mod(stepIdx - 1, obj.RollingWindow) + 1;
      else
          slot = stepIdx;
      end
      U = obj.U_Hist(:, slot);
  end
  ```

- [ ] **6.4** Update the dependent property `U_Hist` getter to reconstruct the correct ordered slice when in rolling mode. In `all` mode the existing logic is unchanged.

- [ ] **6.5** Local verification: run a 200-step analysis with `RollingWindow = 50`. Assert that peak `whos` memory for `obj.U_Hist` is `nDofs * 50 * 8` bytes (not 200). Assert that `getU(1)` throws the eviction error. Assert that `getU(160)` returns the correct vector.

**Gate 6:** Rolling memory test passes (correct memory size AND eviction error fires).

---

### Bug 7 — DispControlStrategy `ControlDOF_local` uninitialized

**File:** `src/@DispControlStrategy/DispControlStrategy.m`

- [ ] **7.1** Move the DOF mapping from `predictor()` into the constructor or a dedicated `initialize(free_dofs)` method called once before the corrector loop. The `ControlDOF_local` property must be set before `constraint()` can be called.

- [ ] **7.2** Add a guard at the top of `constraint()`:
  ```matlab
  if obj.ControlDOF_local < 1
      error('DispControlStrategy:notInitialized', ...
            'Call initialize(free_dofs) before constraint().');
  end
  ```

- [ ] **7.3** In `solveIncrementalStage.m`, after the strategy is retrieved via `Stage.getStrategy()`, call `strategy.initialize(free_dofs)` if the strategy is a `DispControlStrategy`.

- [ ] **7.4** Local verification: construct a `DispControlStrategy`, call `constraint()` before `initialize()`, and assert the error fires. Then call `initialize()` and assert `constraint()` runs without error.
- [ ] **7.5** Implementation of `tests/unit/test_convergence_monitor.m` (Early Priority).
- [ ] **7.6** Create `run_wave1_gates.m` to orchestrate verification for all Wave 1 bugs.

**Wave 1 completion gate:** All seven bug-gate tests plus ConvergenceMonitor tests pass via `run_wave1_gates.m`.

---

## Wave 2 — Data manager embedding

### Task 8 — Replace O(N) MAT append with `matfile()` streaming

**File:** `src/@FEM_DataManager/writeStep_.m`

- [ ] **8.1** Replace the load-entire-file-modify-save pattern with direct column append using MATLAB's `matfile()` API:
  ```matlab
  function writeStep_(obj, stageIdx, stepData)
      n = obj.incrementStepCounter_(stageIdx);
      stageDir = obj.stagePath_(stageIdx);
      uFile = fullfile(stageDir, 'U_hist.mat');
      lFile = fullfile(stageDir, 'lambda_hist.mat');

      mU = matfile(uFile, 'Writable', true);
      if ~isprop(mU, 'U') || isempty(mU, 'U')
          mU.U = stepData.U;          % first step: create variable
      else
          [~, c] = size(mU, 'U');
          mU.U(:, c+1) = stepData.U; % subsequent: append column
      end

      mL = matfile(lFile, 'Writable', true);
      if ~isprop(mL, 'lambda') || isempty(mL, 'lambda')
          mL.lambda = stepData.lambda;
          mL.iters  = stepData.iters;
          mL.time   = stepData.time;
      else
          [~, c] = size(mL, 'lambda');
          mL.lambda(1, c+1) = stepData.lambda;
          mL.iters(1, c+1)  = stepData.iters;
          mL.time(1, c+1)   = stepData.time;
      end
  end
  ```

- [ ] **8.2** For GP history, write each step as a separate variable `gp_NNNNN` in `gp_history.mat` using `matfile()`. No struct-load-modify-save cycle:
  ```matlab
  if isfield(stepData, 'GPHistory') && ~isempty(stepData.GPHistory)
      gpFile = fullfile(stageDir, 'gp_history.mat');
      mGP = matfile(gpFile, 'Writable', true);
      varName = sprintf('gp_%05d', n);
      mGP.(varName) = stepData.GPHistory;
  end
  ```

- [ ] **8.3** Update `loadStageHistory.m` to read from the new `U_hist.mat` and `lambda_hist.mat` format instead of `steps.mat`.

- [ ] **8.4** Update `loadSingleStep_.m` to read a single column from `matfile()` without loading the full array.

- [ ] **8.5** Update `restartFromCheckpoint.m` and `restartFromStep.m` to use the new format. Checkpoint writing (`writeCheckpoint_.m`) remains as a full-state MAT save — this is intentional.

- [ ] **8.6** Local verification: run a 100-step analysis, measuring wall-clock time for each `writeStep_` call. Assert that time per step is O(1) (flat, not growing). Specifically: `time(step_100) < 3 * time(step_1)`.

**Gate 8:** IO scaling test passes.

---

### Task 9 — Decouple DataManager listener from Sol reference

**Files:** `src/@FEM_DataManager/attachToSolver.m`, `src/@FEM_DataManager/onStepConverged_.m`, `src/@SolverEventData/SolverEventData.m`

- [ ] **9.1** Add a `PlasticSnapshot` field to `SolverEventData`:
  ```matlab
  properties
      Time
      StepNumber
      U
      LoadFactor
      Iterations
      ArcUsed        % arc-length radius that converged (0 if N/A)
      PlasticSnapshot % cell{nElems} of HistoryData, or [] if elastic
  end
  ```

- [ ] **9.2** In `solveIncrementalStage.m`, populate `PlasticSnapshot` in the event data before calling `notify`:
  ```matlab
  plasticSnap = [];
  if obj.hasMaterialPlastic()
      plasticSnap = cellfun(@(e) e.HistoryData, obj.Elements, ...
                            'UniformOutput', false);
  end
  evtData = SolverEventData(obj.Time + accumulated, obj.StepCount, ...
                            u_converged, lambda, iters_used, ...
                            trial_ds, plasticSnap);
  notify(obj, 'StepConverged', evtData);
  ```

- [ ] **9.3** Rewrite `onStepConverged_.m` to use only `evt` fields — remove the `Sol` argument entirely:
  ```matlab
  function onStepConverged_(obj, evt, stageIdx)
      stepData.U         = evt.U;
      stepData.lambda    = evt.LoadFactor;
      stepData.iters     = evt.Iterations;
      stepData.time      = evt.Time;
      stepData.arc_used  = evt.ArcUsed;
      if ~isempty(evt.PlasticSnapshot)
          stepData.GPHistory = evt.PlasticSnapshot;
      end
      obj.writeStep_(stageIdx, stepData);
  end
  ```

- [ ] **9.4** Update `attachToSolver.m` so the listener signature no longer passes `Sol`:
  ```matlab
  lh = addlistener(Sol, 'StepConverged', ...
      @(~, evt) obj.onStepConverged_(evt, stageIdx));
  ```

- [ ] **9.5** In `delete.m`, verify all listeners are properly removed. After `delete(obj)`, `isvalid(obj.Listeners_{1})` must return false.

- [ ] **9.6** Local verification: create a `FEM_DataManager`, attach it to a solver, run a 5-step analysis, then clear the solver variable. Confirm the `DataManager` object itself is collectable (does not hold the solver alive). Use `memory()` or `whos` before and after.

**Gate 9:** Listener decoupling test passes; no solver reference retained after clear.

---

### Task 10 — Enforce snapshot-only postprocessor access

**File:** `src/@FEM_Postprocessor_v2/FEM_Postprocessor_v2.m`

- [ ] **10.1** Change the constructor to accept **either** a `SolutionSnapshot` or a live solver, but store a snapshot internally either way:
  ```matlab
  function obj = FEM_Postprocessor_v2(model, solverOrSnapshot)
      obj.Model = model;
      if isa(solverOrSnapshot, 'SolutionSnapshot')
          obj.Snap = solverOrSnapshot;
      elseif isa(solverOrSnapshot, 'FEM_Solver')
          obj.Snap = solverOrSnapshot.state.snapshot();
      else
          error('FEM_Postprocessor_v2:badArg', ...
                'Second argument must be FEM_Solver or SolutionSnapshot.');
      end
  end
  ```

- [ ] **10.2** Replace all internal references to `obj.Solver` with `obj.Snap`. The `Solver` property is removed from the class definition. Add a `Snap` property of type `SolutionSnapshot`.

- [ ] **10.3** Update `getDisplacementAtStep.m` to call `obj.Snap.getU(stepIdx)` instead of `obj.Solver.U_Hist(:, stepIdx)`.

- [ ] **10.4** Update `recoverAllGaussPoints.m`: the plastic archive lookup now reads from `obj.Snap.PlasticHistoryArchive`. When the archive is missing for a requested step, throw an explicit error — do not silently fall back:
  ```matlab
  if isempty(obj.Snap.PlasticHistoryArchive{stepIdx})
      error('FEM_Postprocessor_v2:noArchive', ...
            'No plastic archive for step %d. Run with SaveGPHistory=true.', stepIdx);
  end
  ```

- [ ] **10.5** Update `animateHistory.m`, `plotField.m`, `plotPlasticYield.m`, and `plotReactionDispCurve.m` to use `obj.Snap` fields.

- [ ] **10.6** Local verification: construct `FEM_Postprocessor_v2` from a solver, then clear the solver variable. Call `Post.recoverField('von_mises', 1)` and assert it succeeds (snapshot holds all needed data independently).

**Gate 10:** Postprocessor isolation test passes.

---

### Task 11 — Fix `recoverAllGaussPoints` mixed-step silent fallback

**File:** `src/@FEM_Postprocessor_v2/recoverAllGaussPoints.m`

- [ ] **11.1** At the point where the archive lookup fails, replace the silent fallback with a named warning that includes the step index and element index:
  ```matlab
  warning('FEM_Postprocessor_v2:archiveMiss', ...
          'No plastic archive at step %d elem %d. Using live state.', stepIdx, e);
  ```
  This warning must be suppressible via `warning('off', 'FEM_Postprocessor_v2:archiveMiss')` for batch runs.

- [ ] **11.2** Add a public method `hasArchive(stepIdx)` that returns `true` if the archive is complete for that step.
- [ ] **11.3** Create `run_wave2_gates.m`.

**Wave 2 completion gate:** All task gates 8–11 pass via `run_wave2_gates.m`.

---

## Wave 3 — Decomposition and assembly consolidation

### Task 12 — Single authoritative assembly interface

**Files:** `src/@FEM_Solver/assembleTangentSystem.m`, all callers

- [ ] **12.1** Delete `assembleTangentSystem.m` from `src/@FEM_Solver/`. This method is a thin wrapper that adds one indirection layer and hides the `obj.U` default argument.

- [ ] **12.2** Replace all call sites with direct `Assembler.tangent(U, obj.Elements, obj.SctrMap, nDofs)` calls:
  - `src/@FEM_Solver_Nonlinear/solveIncrementalStage.m` — the closure body
  - `src/@FEM_Solver_Nonlinear/newtonLoop.m` — already done (uses `Assembler.tangent`)
  - Any other file found by `grep -r assembleTangentSystem src/`

- [ ] **12.3** Verify `Assembler.tangent` is the sole assembly path. `grep -r assembleTangentSystem src/` must return zero results.

- [ ] **12.4** Similarly verify `assembleinternalforceONLY` is only called from `linesearch.m` and `armijoSearch.m`, and that it delegates to `Assembler.internalForce`:
  ```matlab
  function F_int = assembleinternalforceONLY(obj, U_trial)
      nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
      F_int = Assembler.internalForce(U_trial, obj.Elements, obj.SctrMap, nDofs);
  end
  ```

**Gate 12:** Zero results for `assembleTangentSystem` in `src/`; integration test passes.

---

### Task 13 — Extract `correctorLoop` from `solveIncrementalStage`

**File:** `src/@FEM_Solver_Nonlinear/solveIncrementalStage.m`

- [ ] **13.1** Extract the inner Newton corrector (approximately lines 100–210 of the current file) into a new private method:
  ```matlab
  % src/@FEM_Solver_Nonlinear/correctorLoop.m
  function [u_out, l_out, F_int, TrialHist, converged, iters] = ...
           correctorLoop(obj, u0, l0, strategy, ds, assembleFn, free_dofs, u_pred, l_pred, dup_step, dlp)
  ```
  The method must have **no side effects** — it does not call `commitHistory`, does not write to `obj.state`, and does not call `notify`. It is a pure solver returning the converged state.

- [ ] **13.2** Extract the accept-and-archive sequence into a private method:
  ```matlab
  % src/@FEM_Solver_Nonlinear/acceptStep.m
  function acceptStep(obj, u_converged, lambda, F_int_conv, TrialHist, fixed_dofs, trial_ds)
  ```
  This method performs: `commitHistory`, `obj.state.appendStep`, `notify(StepConverged)` — exactly in that order.

- [ ] **13.3** The main `solveIncrementalStage.m` body becomes the orchestration loop only: stage setup → predictor → trial loop calling `correctorLoop` → on success call `acceptStep`. Target length: ≤ 120 lines.

- [ ] **13.4** Verify the refactored `solveIncrementalStage.m` is ≤ 120 lines using `wc -l`.

**Gate 13:** `wc -l solveIncrementalStage.m` ≤ 120; all existing integration tests still pass.

---

### Task 14 — Wire `ConvergenceMonitor.recommend()` to corrector

**File:** `src/@FEM_Solver_Nonlinear/correctorLoop.m`

- [ ] **14.1** After each `mon.check()` call, query `mon.recommend()` and act:
  - `'abort'` → set `converged = false`, break corrector loop immediately
  - `'linesearch'` → force `opts.UseLineSearch = true` for this iteration only
  - `'cutback'` → set `converged = false`, break corrector loop (caller will halve radius)
  - `'continue'` → proceed normally

- [ ] **14.2** Confirm the `recommend()` method uses the thresholds from `SolverOptions`:
  ```matlab
  function reset(obj, F_ext_free, opts)
      ...
      if nargin > 2 && ~isempty(opts)
          if isprop(opts, 'StagnationWindow'), obj.StagnationWin = opts.StagnationWindow; end
          if isprop(opts, 'DivergenceRatio'),  obj.DivRatio = opts.DivergenceRatio;      end
      end
  end
  ```

- [ ] **14.3** Local verification: configure `opts.DivergenceRatio = 1.5` (very sensitive). Run a test where the solver intentionally diverges on step 1. Assert that `converged = false` is returned after fewer iterations than `MaxIterations`.

**Gate 14:** Monitor recommendation test passes.

---

### Task 15 — `SolverOptions` validation and defaults audit

**File:** `src/@SolverOptions/SolverOptions.m`

- [ ] **15.1** Add a `validate()` method that checks all critical properties and throws descriptive errors:
  ```matlab
  function validate(obj)
      assert(obj.MaxIterations >= 3, 'MaxIterations must be >= 3');
      assert(obj.TolForce > 0 && obj.TolForce < 1, 'TolForce must be in (0,1)');
      assert(obj.MinDt > 0 && obj.MinDt < obj.MaxDt, 'MinDt must be > 0 and < MaxDt');
      assert(obj.LBFGSHistory >= 1, 'LBFGSHistory must be >= 1');
      validNorms = {'force', 'energy', 'displacement'};
      assert(ismember(obj.NormType, validNorms), 'NormType must be force|energy|displacement');
      validModes = {'all', 'rolling'};
      assert(ismember(obj.MemoryMode, validModes), 'MemoryMode must be all|rolling');
  end
  ```

- [ ] **15.2** Call `opts.validate()` at the top of `FEM_Solver_Nonlinear.solve()`.

- [ ] **15.3** Remove all deprecated alias properties (`Tolerance`, `tol`, `maxIter`, `linesearch`, `UseLBFGS`). These were kept for backward compatibility; with legacy code deleted they are dead.
- [ ] **15.4** Create `run_wave3_gates.m`.

**Wave 3 completion gate:** All task gates 12–15 pass via `run_wave3_gates.m`.

---

## Wave 4 — Test suite implementation

All test files must follow this structure:

```matlab
% File: tests/unit/test_XXXX.m
function results = test_XXXX()
% Returns a struct with fields: passed (logical), name (string), details (string)
results = struct('passed', false, 'name', 'test_XXXX', 'details', '');
try
    % ... test body ...
    results.passed = true;
    results.details = 'All assertions passed';
catch ME
    results.details = ME.message;
end
end
```

`run_all_tests.m` must collect all results and fail with a non-zero exit code if any test fails.

---

### Unit tests

#### `tests/unit/test_assembler.m`

- [ ] **UT1.1** Test `Assembler.elastic` on a single 8-node element (flat plate). Assert stiffness matrix is symmetric: `norm(K - K', 'fro') < 1e-10`.
- [ ] **UT1.2** Assert `rank(K) == 40 - 6` (rigid body modes removed) before BCs, `rank(K_ff) == length(free_dofs)` after BCs.
- [ ] **UT1.3** Test `Assembler.internalForce` at zero displacement returns a zero vector: `norm(F_int) < 1e-12`.
- [ ] **UT1.4** Test `Assembler.tangent` at zero displacement matches `Assembler.elastic` result: `norm(KT - K, 'fro') / norm(K, 'fro') < 1e-10`.
- [ ] **UT1.5** Test assembly scaling: 100-element mesh assembly time must be < 5 seconds on any machine.

#### `tests/unit/test_convergence_monitor.m` (Moved to Wave 1)

- [ ] **UT2.1** Test force norm: construct monitor, call `reset`, call `check` with `||R|| / ||F_ext|| < tol`. Assert `check` returns `true`.
- [ ] **UT2.2** Test energy norm: pass non-empty `dU_free`. Assert `ResidualHistory(1) > 0` (not trivially zero).
- [ ] **UT2.3** Test displacement norm: pass `U_total_free`. Assert `ResidualHistory(1) > 0`.
- [ ] **UT2.4** Test `isDiverging`: feed residuals `[1, 10, 100, 1000]`. Assert `isDiverging()` returns `true` with `DivergenceRatio = 500`.
- [ ] **UT2.5** Test `isStagnating`: feed residuals `[1, 0.99, 0.98, 0.97]` over 4 steps. Assert `isStagnating()` returns `true` (< 5% reduction in window).
- [ ] **UT2.6** Test `isOscillating`: feed residuals `[1, 2, 1, 2]`. Assert `isOscillating()` returns `true`.
- [ ] **UT2.7** Test `recommend()` returns `'abort'` when diverging, `'cutback'` when stagnating.

#### `tests/unit/test_curve8element.m`

- [ ] **UT3.1** Test `fmisoq8` at all 4 corner nodes: `N(xi_n, eta_n)` must equal the identity row (1 at own node, 0 at all others). Tolerance: `< 1e-14`.
- [ ] **UT3.2** Test partition of unity: `sum(N) == 1` at 25 random points. Tolerance: `< 1e-13`.
- [ ] **UT3.3** Test shape function derivatives: numerical Jacobian (finite differences) vs analytic `der`. Max error: `< 1e-7`.
- [ ] **UT3.4** Test `getConstitutiveMatrix`: assert `D_mb` is symmetric positive-definite (all eigenvalues > 0).
- [ ] **UT3.5** Test `computeStiffnessMatrix` on a flat plate element: assert symmetry and positive semi-definiteness.
- [ ] **UT3.6** Test `Trans_T`: assert `T * T' = I` to machine precision (T is orthogonal).
- [ ] **UT3.7** Test `computeGlobalMatrix6DOF`: at zero displacement, `fe_global` is zero vector (no residual at unloaded reference config).

#### `tests/unit/test_material_j2plastic.m`

- [ ] **UT4.1** Elastic trial below yield: `sigma_new == D_el * eps_total`, `p_new == p_old == 0`.
- [ ] **UT4.2** Plastic return mapping: apply strain above yield threshold. Assert `von_mises(sigma_new) <= sigma_Y + H * p_new + tol`.
- [ ] **UT4.3** Algorithmic tangent consistency check: perturb `eps_total` by `delta_eps`. Verify `sigma_new(eps + delta) - sigma_new(eps) ≈ Dep * delta_eps`. Max relative error: `< 1e-5`.
- [ ] **UT4.4** Conservation of volume (plastic incompressibility): assert `trace(eps_p_new - eps_p_old) ≈ 0`. Tolerance: `< 1e-10`.
- [ ] **UT4.5** Convergence of local Newton loop: verify that for 50 random strain inputs above yield, the loop converges (no warning fires). Max iterations: 20.

#### `tests/unit/test_solution_state.m`

- [ ] **UT5.1** `all` mode: append 10 steps, assert `StepCount == 10`, `size(U_Hist, 2) == 10`.
- [ ] **UT5.2** `rolling` mode with `RollingWindow = 5`: append 20 steps. Assert `getU(20)` succeeds. Assert `getU(14)` throws `SolutionState:evicted`. Assert memory for `U_Hist` is `nDofs * 5 * 8` bytes.
- [ ] **UT5.3** `snapshot()` returns a `SolutionSnapshot` with `StepCount == n` and `U_Hist` is a copy (modifying snapshot does not modify state).
- [ ] **UT5.4** `beginStage()` increments `StageCount`. After 3 `beginStage` calls, `StageCount == 3`.
- [ ] **UT5.5** `setEigenResults` stores modes; `snapshot().ModeShapes` matches what was set.

#### `tests/unit/test_incremental_strategies.m`

- [ ] **UT6.1** `RiksStrategy.predictor`: assert `norm(dup_f - KT_ff \ F_ext_f) < 1e-12` (predictor solves tangent system correctly).
- [ ] **UT6.2** `RiksStrategy.constraint`: at the predictor point `(u1, l1)`, `g == 0` exactly.
- [ ] **UT6.3** `LoadControlStrategy.constraint`: assert `g == lambda - (l0 + ds)`.
- [ ] **UT6.4** `DispControlStrategy`: after `initialize(free_dofs)`, assert `ControlDOF_local > 0`. Assert `constraint` returns `g = u_f(dof_local) - (u0_f(dof_local) + ds)`.
- [ ] **UT6.5** `adaptRadius`: feed `iters = 2` (easy) → assert radius increases by factor 1.5 up to `ArcLengthMax`. Feed `iters = 20, maxIter = 25` → assert radius decreases by factor 0.7 down to `ArcLengthMin`.

#### `tests/unit/test_data_manager.m`

- [ ] **UT7.1** `initProject` creates `project_meta.json` with correct fields.
- [ ] **UT7.2** `writeStep_` with 50 steps: assert that step 50 write time < 3× step 1 write time (O(1) scaling).
- [ ] **UT7.3** `loadSingleStep_` on step 25 returns `U` of correct size without loading all 50 steps.
- [ ] **UT7.4** `restartFromCheckpoint` reconstructs a solver with `StepCount == CheckpointInterval`.
- [ ] **UT7.5** `delete(DataManager)` fires all listeners and they become invalid.

#### `tests/unit/test_solver_options.m`

- [ ] **UT8.1** Default construction: assert all defaults match spec (`MaxIterations == 25`, `TolForce == 1e-4`, etc.).
- [ ] **UT8.2** `validate()` passes on a default `SolverOptions()`.
- [ ] **UT8.3** `validate()` throws when `MaxIterations < 3`.
- [ ] **UT8.4** `validate()` throws when `NormType = 'bad_norm'`.
- [ ] **UT8.5** `validate()` throws when `MinDt >= MaxDt`.

---

### Integration tests

#### `tests/integration/test_elastic_plate_linear.m`

- [ ] **IT1.1** 4×4 mesh, 1 m × 1 m plate, clamped edges, uniform pressure 1 kPa. Run `solveStatic`. Assert max `|U_z|` within 5% of thin-plate analytical solution `w_max = 0.00126 * q*a^4 / (E*t^3)`.
- [ ] **IT1.2** Assert `Sol.BucklingFactors` is empty before `solveBuckling`.
- [ ] **IT1.3** Run `solveBuckling(3)`. Assert 3 positive eigenvalues returned. Assert first eigenvalue `lambda_1 > 0`.
- [ ] **IT1.4** Assert `FEM_Postprocessor_v2` can be constructed from the solver and returns `von_mises` field of length `nNodes`.

#### `tests/integration/test_elastic_plate_nonlinear.m`

- [ ] **IT2.1** Same plate, load applied in 5 steps via `LoadControlStrategy`. Assert `Sol.StepCount == 5`.
- [ ] **IT2.2** Assert `Sol.U_Hist` has 5 columns and each column has increasing `max(abs(U_z))`.
- [ ] **IT2.3** Assert `Sol.state.StepCount == 5` (consistent with dependent property).
- [ ] **IT2.4** Assert `FEM_Postprocessor_v2.recoverField('displacement_z', 5)` matches `Sol.U(3:6:end)`.

#### `tests/integration/test_plastic_plate.m`

- [ ] **IT3.1** Plate with `Material_J2Plastic`, 10 load steps. Assert `Sol.StepCount == 10`.
- [ ] **IT3.2** Assert that at step 10 at least one GP has `p > 0` (yielding actually occurred).
- [ ] **IT3.3** Assert `Sol.state.PlasticHistoryArchive{10}` is non-empty.
- [ ] **IT3.4** Assert that `FEM_Postprocessor_v2.recoverField('p', 10)` has `max(field) > 0`.
- [ ] **IT3.5** Assert plastic archive consistency: for each element `e`, `Sol.state.PlasticHistoryArchive{5}{e}(1).p <= Sol.state.PlasticHistoryArchive{10}{e}(1).p` (plastic strain is monotone non-decreasing).

#### `tests/integration/test_cylindrical_panel_snapthrough.m`

- [ ] **IT4.1** Hinged cylindrical panel (Riks benchmark geometry: R=2540, L=508, t=5, angle=0.1). Apply central load via `RiksStrategy`. Run 20 steps. Assert `Sol.StepCount == 20`.
- [ ] **IT4.2** Assert that `Sol.LambdaHist` is NOT monotonically increasing (snap-through produces load reversal). Specifically: `min(diff(Sol.LambdaHist)) < 0`.
- [ ] **IT4.3** Assert crown displacement monotonically increases (even as load reverses).
- [ ] **IT4.4** Assert no step took more than `MaxIterations` iterations (check via `Sol.state.ArcLengthHist` — all values > 0 means each step converged).

#### `tests/integration/test_buckling_eigenvalue.m`

- [ ] **IT5.1** Simply supported square plate, uniform compression. Run `solveStatic` then `solveBuckling(3)`. Assert first buckling factor within 5% of analytical `lambda_cr = pi^2 * D / (a^2 * N_x)`.
- [ ] **IT5.2** Assert `Sol.ModeShapes` has 3 columns of length `nDofs`.
- [ ] **IT5.3** Assert mode shapes are mass-normalized: each column has `max(abs(phi)) == 1`.

#### `tests/integration/test_data_manager_pipeline.m`

- [ ] **IT6.1** Full pipeline: `initProject` → `initStage` → `attachToSolver` → 10-step solve → `finalizeStage` → `finalizeProject`. Assert `project_meta.json` has `status == 'complete'`.
- [ ] **IT6.2** Restart: call `restartFromCheckpoint(1)`. Assert returned `Sol.StepCount == CheckpointInterval`.
- [ ] **IT6.3** Call `loadStageHistory(1)`. Assert `size(U_hist, 2) == 10` and `length(lambda_hist) == 10`.
- [ ] **IT6.4** Assert `listRestartPoints()` returns a struct with `nSteps == 10` for stage 1.

---

### Verification tests

These tests check numerical correctness against published reference solutions. Each must report an error percentage.

#### `tests/verification/verify_patch_test.m`

The patch test verifies that a mesh of distorted elements can represent a constant-stress state exactly.

- [ ] **VT1.1** Create a 2×2 mesh of distorted 8-node elements. Apply linear displacement boundary conditions consistent with a constant `sigma_x = 1` Pa state.
- [ ] **VT1.2** Solve the static problem. Recover `SigmaX` at all nodes via `recoverField`.
- [ ] **VT1.3** **Pass criterion:** `max(abs(SigmaX - 1)) < 1e-8` at all nodes. The patch test must pass to machine precision.

#### `tests/verification/verify_beam_bending.m`

Cantilever beam: E=210 GPa, nu=0.3, t=0.01 m, L=1 m, w=0.1 m. Tip load F=1 N.

- [ ] **VT2.1** Run linear static analysis with 4 elements along length.
- [ ] **VT2.2** Compute tip deflection `delta_tip = Sol.U(tip_z_dof)`.
- [ ] **VT2.3** Analytical solution: `delta = F*L^3 / (3*E*I)` where `I = t*w^3/12`.
- [ ] **VT2.4** **Pass criterion:** `|delta_tip - delta_analytical| / delta_analytical < 0.02` (2% error tolerance).

#### `tests/verification/verify_scordelis_lo_roof.m`

Scordelis–Lo barrel vault (NAFEMS benchmark). R=25, L=50, t=0.25, 18°-18° subtended angle. E=4.32e8, nu=0. Weight per unit area = 90.

- [ ] **VT3.1** Build mesh with 4×4 elements per quadrant (exploit symmetry: one quarter model).
- [ ] **VT3.2** Apply self-weight body force.
- [ ] **VT3.3** Reference solution: vertical displacement at midpoint of free edge = -0.3024 (normalised).
- [ ] **VT3.4** **Pass criterion:** `|u_z_ref - u_z_computed| / |u_z_ref| < 0.02`.

#### `tests/verification/verify_cylindrical_panel_riks.m`

Crisfield snap-through benchmark (1981). R=2540, L=508, t=12.7, E=3102.75, nu=0.3. Central point load.

- [ ] **VT4.1** Apply imperfection equal to first buckling mode scaled to t/100.
- [ ] **VT4.2** Run `RiksStrategy` arc-length analysis.
- [ ] **VT4.3** Reference peak load: `P_cr = 640 N` (Crisfield 1981, Table 1).
- [ ] **VT4.4** **Pass criterion:** `|P_peak - 640| / 640 < 0.05` (5% tolerance on peak load).
- [ ] **VT4.5** Snap-through must be captured: `min(diff(LambdaHist)) < 0`.

#### `tests/verification/verify_plastic_thick_plate.m`

Circular plate under uniform pressure. Clamped edge. E=200 GPa, nu=0.3, sigma_Y=250 MPa, H=0. Thickness=10 mm, R=100 mm.

- [ ] **VT5.1** Run 20 load steps with plasticity enabled.
- [ ] **VT5.2** Reference full-plasticity load from limit analysis: `P_lim = 6 * sigma_Y * t^2 / R^2` (Johansen yield-line, approximate).
- [ ] **VT5.3** **Pass criterion:** The load at which the plate becomes fully plastic (entire thickness yielded at center) must fall within 10% of `P_lim`.
- [ ] **VT5.4** Assert that the load-displacement curve is monotonically non-decreasing up to full plasticity.

#### `tests/verification/verify_replay_determinism.m`

- [ ] **VT6.1** Run a 15-step Riks analysis on the cylindrical panel. Save `SolutionSnapshot` to disk.
- [ ] **VT6.2** Load the snapshot. Construct `FEM_Postprocessor_v2` from the snapshot.
- [ ] **VT6.3** Recover `von_mises` at step 15 both from the live solver (before clearing) and from the loaded snapshot.
- [ ] **VT6.4** **Pass criterion:** `max(abs(vm_live - vm_replay)) < 1e-8`. The fields must be bit-for-bit identical.
- [ ] **VT6.5** Assert that the snapshot is truly independent: clear the solver object, then call `Post.recoverField('von_mises', 15)` and assert it still succeeds.

---

### Benchmark tests

#### `tests/benchmarks/bench_assembly_scaling.m`

- [ ] **BM1.1** Run `Assembler.elastic` for mesh sizes: 100, 400, 900, 1600 elements. Record wall-clock time.
- [ ] **BM1.2** Fit a power law `T = a * N^b`. **Pass criterion:** `b < 1.15` (near-linear scaling).
- [ ] **BM1.3** Assert 1600-element elastic assembly completes in < 30 seconds.

#### `tests/benchmarks/bench_solver_convergence.m`

- [ ] **BM2.1** Run the cylindrical panel snap-through with each of: `RiksStrategy`, `LoadControlStrategy`, `DispControlStrategy`. Record: steps to complete 20 arc-length increments, mean iterations per step.
- [ ] **BM2.2** Run the same problem with `UseQuasiNewton = false` vs `UseQuasiNewton = true`. Record: mean iterations per step.
- [ ] **BM2.3** **Pass criterion (L-BFGS):** `mean_iters_lbfgs <= mean_iters_newton * 1.2` (L-BFGS must not be worse than Newton by more than 20%).
- [ ] **BM2.4** **Pass criterion (Riks):** completes 20 steps in < 60 seconds on a single core.

#### `tests/benchmarks/bench_datamanager_io.m`

- [ ] **BM3.1** Write 500 steps via `FEM_DataManager.writeStep_`. Record wall-clock time per step.
- [ ] **BM3.2** Assert that `time(step_500) / time(step_1) < 3.0` (flat, not growing).
- [ ] **BM3.3** Read back each of the 500 steps individually via `loadSingleStep_`. Assert total read time < 10 seconds.
- [ ] **BM3.4** Verify written files do not exceed `nDofs * nSteps * 8 * 1.05` bytes (≤ 5% overhead from format).

---

## `run_all_tests.m` — master test runner

```matlab
% tests/run_all_tests.m
% Execute all tests. Exit with code 1 if any fail.
function run_all_tests()
    addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src')));

    suites = {
        % Unit
        'unit/test_assembler',
        'unit/test_convergence_monitor',
        'unit/test_curve8element',
        'unit/test_material_j2plastic',
        'unit/test_solution_state',
        'unit/test_incremental_strategies',
        'unit/test_data_manager',
        'unit/test_solver_options',
        % Integration
        'integration/test_elastic_plate_linear',
        'integration/test_elastic_plate_nonlinear',
        'integration/test_plastic_plate',
        'integration/test_cylindrical_panel_snapthrough',
        'integration/test_buckling_eigenvalue',
        'integration/test_data_manager_pipeline',
        % Verification
        'verification/verify_patch_test',
        'verification/verify_beam_bending',
        'verification/verify_scordelis_lo_roof',
        'verification/verify_cylindrical_panel_riks',
        'verification/verify_plastic_thick_plate',
        'verification/verify_replay_determinism',
        % Benchmarks
        'benchmarks/bench_assembly_scaling',
        'benchmarks/bench_solver_convergence',
        'benchmarks/bench_datamanager_io',
    };

    passed = 0; failed = 0; failedNames = {};
    for k = 1:length(suites)
        name = suites{k};
        fprintf('Running %-55s ... ', name);
        try
            fn = str2func(strrep(name, '/', '.'));
            result = feval(strrep(name, '/', filesep));
            if result.passed
                fprintf('PASS\n');
                passed = passed + 1;
            else
                fprintf('FAIL: %s\n', result.details);
                failed = failed + 1;
                failedNames{end+1} = name;
            end
        catch ME
            fprintf('ERROR: %s\n', ME.message);
            failed = failed + 1;
            failedNames{end+1} = name;
        end
    end

    fprintf('\n=== Test summary: %d passed, %d failed ===\n', passed, failed);
    if failed > 0
        fprintf('Failed tests:\n');
        for k = 1:length(failedNames)
            fprintf('  - %s\n', failedNames{k});
        end
        error('run_all_tests:failed', '%d test(s) failed.', failed);
    end
end
```

---

## Final verification gate

**The implementation is considered complete when and only when ALL of the following are true:**

- [ ] **FV1** `run_all_tests.m` exits with code 0 (zero failed tests).
- [ ] **FV2** `grep -r "FEM_Solver_ArcLength\|FEM_Solver_Adaptive\|FEM_Postprocessor[^_v2]\|FEM_Preprocessor_CAD\|GeometryEngine" src/ tests/` returns zero matches.
- [ ] **FV3** `grep -r "assembleTangentSystem" src/` returns zero matches.
- [ ] **FV4** `wc -l src/@FEM_Solver_Nonlinear/solveIncrementalStage.m` reports ≤ 120 lines.
- [ ] **FV5** All six verification tests (`verify_*.m`) print "PASS" with their reference-solution error percentages reported inside tolerance.
- [ ] **FV6** All three benchmark tests report their timing metrics and all "Pass criterion" assertions are met.
- [ ] **FV7** A fresh MATLAB session with only `addpath(genpath('src'))` can run the Scordelis–Lo roof benchmark end to end without any missing class or function errors.
- [ ] **FV8** The `verify_replay_determinism` test passes with `max(abs(vm_live - vm_replay)) < 1e-8`.

---

## Execution order summary

```
Wave 0: Repository cleanup
  └─ W0.1–W0.4 (delete legacy, verify clean)

Wave 1: P0 correctness bugs                [prerequisite for all testing]
  ├─ Bug 1: Residual sign
  ├─ Bug 2: Function shadow
  ├─ Bug 3: Double plastic commit
  ├─ Bug 4: Dual write paths
  ├─ Bug 5: Empty dU in monitor
  ├─ Bug 6: Rolling mode memory
  └─ Bug 7: DispControl initialization

Wave 2: Data manager embedding
  ├─ Task 8: O(1) matfile append
  ├─ Task 9: Listener decoupling
  ├─ Task 10: Snapshot-only postprocessor
  └─ Task 11: Archive fallback warning

Wave 3: Decomposition and consolidation
  ├─ Task 12: Single assembly path
  ├─ Task 13: Extract correctorLoop
  ├─ Task 14: Wire monitor recommendations
  └─ Task 15: SolverOptions validation

Wave 4: Full test suite
  ├─ 8 unit test files (40 test cases)
  ├─ 6 integration test files (24 test cases)
  ├─ 6 verification test files (25 pass criteria)
  └─ 3 benchmark files (12 pass criteria)

Final verification gate (all 8 items checked)
```

---

*End of implementation plan.*
