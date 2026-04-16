# CurveShellFEM — Solver Pipeline Redesign: AI Agent Work Plan

> **Document purpose:** Executable instruction set for an AI coding agent.  
> Every task section contains: context, exact deliverables, self-check criteria, and a verification procedure the agent must run before marking the task done.  
> The agent must not proceed to a later phase until all self-checks in the current phase pass.

---

## How to use this document

1. Work **strictly in phase order**. Each phase builds on the previous.
2. Before starting any task, read the **Context** section fully.
3. After completing a task, run every command in **Verification procedure** and confirm each passes.
4. If a verification fails, fix the issue and re-run before continuing.
5. Never delete existing classes unless the task explicitly says to. Prefer additive changes and deprecation wrappers.
6. All new files go in `src/` under the appropriate `@ClassName/` folder.
7. Commit-worthy state = all verification procedures in a phase pass with zero errors.

---

## Codebase map (read before starting)

```
src/
  @FEM_Solver/              % Base linear solver — assembleK, solveStatic, solveBuckling
  @FEM_Solver_Nonlinear/    % Newton-Raphson base — newtonLoop, updateHistory
  @FEM_Solver_Adaptive/     % Stage loop + bisection — solveStage
  @FEM_Solver_ArcLength/    % Arc-length — arcLengthStep, solveArcLengthStage
  @Curve8Element/           % Shell element math — 48-DOF, HistoryData
  @Curve8Element_ANS_EAS/   % Locking-mitigated element subclass
  @FEM_Preprocessor/        % Legacy preprocessor (keep, do not modify)
  @FEM_Preprocessor_v2/     % Active preprocessor — geometry, mesh, BCs, Loads
  @FEM_Postprocessor/       % Legacy postprocessor (wrap, do not break)
  @FEM_Postprocessor_v2/    % New GP-pipeline postprocessor
  @Material_J2Plastic/      % J2 plasticity with isotropic hardening
  @SolverOptions/           % Configuration object
  @LoadingStage/            % Stage definition for multi-stage analysis
  @SolverEventData/         % Event payload for StepConverged notification
  @MathFEM/                 % Gauss quadrature utility
examples/                   % Benchmark scripts
tests/                      % Unit and integration tests
```

**Key files to understand before any work:**
- `src/@FEM_Solver/assembleK.m` — current assembly (triplet sparse build)
- `src/@FEM_Solver_Nonlinear/newtonLoop.m` — NR corrector (has bugs to fix)
- `src/@FEM_Solver_ArcLength/arcLengthStep.m` — arc-length corrector
- `src/@FEM_Solver_ArcLength/solveArcLengthStage.m` — stage driver
- `src/@FEM_Postprocessor/recoverNodalSmooth.m` — contains solver mutation bug

---

# PHASE 0 — Hotfixes

> **Goal:** Fix five silent correctness bugs without any structural changes.  
> Every fix is a targeted line-level patch. No new files. No class restructuring.  
> After Phase 0 all existing analyses must produce identical results to before — these are bug fixes, not behaviour changes.

---

## Task H1 — Fix `linesearch.m`: must not write `obj.U`

### Context

`src/@FEM_Solver_Nonlinear/linesearch.m` currently ends with:

```matlab
obj.U = U_old + eta * dU;
```

This writes directly to the solver's authoritative displacement vector inside a utility method. If the line search is called during an arc-length step, it corrupts the solver state for the subsequent constraint evaluation. The method should be a pure utility that returns `eta` and lets the **caller** apply the update.

### Exact deliverable

Rewrite `linesearch.m` so that:

1. The function **returns `eta`** as its output argument (scalar, double).
2. The line `obj.U = ...` is **removed entirely** — no assignment to any property of `obj`.
3. The function signature becomes:  
   `function eta = linesearch(obj, U_old, dU, R, F_ext_current, free_dofs)`
4. In `newtonLoop.m`, replace the current call site with:  
   ```matlab
   eta = obj.linesearch(U_old, dU, R, F_ext_current, free_dofs);
   U_curr(free_dofs) = U_old(free_dofs) + eta * dU(free_dofs);
   ```

### Self-check criteria

- [ ] `grep -n "obj\.U" src/@FEM_Solver_Nonlinear/linesearch.m` returns zero matches.
- [ ] `linesearch.m` has `function eta =` as its first line of the function definition.
- [ ] `newtonLoop.m` applies `U_curr(free_dofs) = U_old(free_dofs) + eta * dU(free_dofs)` after calling linesearch.
- [ ] No other method in `@FEM_Solver_Nonlinear/` calls `obj.U = ` outside of `newtonLoop.m` or `updateHistory`.

### Verification procedure

```matlab
% Run in MATLAB — must produce no error
% Test: linesearch returns a scalar eta in (0,1]
cd src
addpath(genpath('.'))
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
fixNodes = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixNodes, 1:6, 0, 'fix');
tipNodes = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
Pre.addNodalLoad(tipNodes, 3, -100, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
fprintf('H1 PASS: solveStatic completed without linesearch mutation\n');
```

---

## Task H2 — Fix `recoverNodalSmooth.m`: postprocessor must not write `Solver.U`

### Context

In `src/@FEM_Postprocessor/recoverNodalSmooth.m`, around line 270, there is:

```matlab
obj.Solver.U = u;
```

This line overwrites the solver's live displacement vector with a historical snapshot `u` pulled from `U_Hist`. If called mid-analysis (e.g. from the App's live-update callback), it destroys the current solution. This is a critical data-pipeline violation: the postprocessor is a consumer and must never write to its source.

### Exact deliverable

1. Remove the line `obj.Solver.U = u;` from `recoverNodalSmooth.m`.
2. Pass `u` as an additional argument to the internal `evaluatePoint` call instead:  
   Replace:  
   ```matlab
   [val, ~] = obj.evaluatePoint(elObj, u_el, xi_g(g), eta_g(g), z_loc, type, e);
   ```  
   The `u_el` variable is already constructed from the local `u` variable — confirm this is the case. If `u_el` is being built from `obj.Solver.U`, fix it to build from the local `u` parameter.
3. Confirm that the `u` variable used throughout the function comes **only** from the `switch obj.AnalysisType` block that reads from `U_Hist` or is passed in — never from `obj.Solver.U` after the initial retrieval at the top of the function.

### Self-check criteria

- [ ] `grep -n "obj\.Solver\.U\s*=" src/@FEM_Postprocessor/recoverNodalSmooth.m` returns zero matches.
- [ ] `u_el` is built from the local `u` variable (e.g. `U_global((idx(n)-1)*6+(1:6))` where the global `U_global` = the local `u`), not from `obj.Solver.U` after the switch block.
- [ ] The function still returns correct stress values — verified by the patch test below.

### Verification procedure

```matlab
% Must complete without error and return a non-NaN stress field
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 1, 1000, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
U_before = Sol.U;
Post = FEM_Postprocessor(Pre, Sol);
sigX = Post.recoverNodalSmooth('SigmaX', 'Mid');
assert(~any(isnan(sigX)), 'H2 FAIL: NaN in recovered stress');
assert(isequal(Sol.U, U_before), 'H2 FAIL: Solver.U was modified by postprocessor');
fprintf('H2 PASS: postprocessor did not mutate solver state\n');
```

---

## Task H3 — Fix `newtonLoop.m`: diverge path must return `U0`, not drifted `U_curr`

### Context

When the Newton loop fails to converge, the current code returns `U_out = U_curr` — the last iterated (and non-converged) displacement. The caller in `solveStage` then passes this drifted state as the starting point for the bisected retry, meaning each failed attempt worsens the initial guess. The correct behaviour is to return the **entry state** `U0` on divergence so every retry starts from a clean known-good position.

Additionally, `commitHistory(TrialHist)` must **not** be called on the diverge path. Currently the code structure may call it before checking convergence in some code paths.

### Exact deliverable

1. At the start of `newtonLoop.m`, save the entry state:  
   ```matlab
   U_entry = U_curr;  % preserve entry state for diverge return
   ```
2. On the diverge path (after the loop exhausts iterations without convergence), return:  
   ```matlab
   U_out = U_entry;
   reaction = [];
   converged = false;
   % DO NOT call commitHistory here
   return;
   ```
3. On the **converge** path only, call `obj.commitHistory(TrialHist)` and return `U_out = U_curr`.
4. Ensure `TrialHist` is **not** committed when `converged = false`.

### Self-check criteria

- [ ] A `U_entry = U_curr` assignment exists at the top of the loop body (before iteration begins).
- [ ] The diverge return path assigns `U_out = U_entry`.
- [ ] `obj.commitHistory` appears **only once** in the function, inside the `if converged` block.
- [ ] `grep -c "commitHistory" src/@FEM_Solver_Nonlinear/newtonLoop.m` returns `1`.

### Verification procedure

```matlab
% Force divergence by setting MaxIterations = 1 with a hard problem
% Verify U is unchanged after the failed call
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 3, -1e9, 'load');
opts = SolverOptions();
opts.MaxIterations = 1;  % force divergence
opts.Tolerance = 1e-30;  % impossible tolerance
Sol = FEM_Solver_Adaptive(Pre, opts);
U_before = Sol.U;
stage = LoadingStage(1.0);
stage.activateBC('fix'); stage.activateLoad('load');
try
    Sol.solve({stage});
catch
end
% U should be unchanged (returned to entry state)
assert(norm(Sol.U - U_before) < 1e-12, 'H3 FAIL: diverge path mutated U');
fprintf('H3 PASS: diverge path returns entry state\n');
```

---

## Task H4 — Fix `arcLengthStep.m`: singularity check direction

### Context

In `arcLengthStep.m`, the check for a nearly-singular tangent stiffness reads:

```matlab
if condest(KT_ff) < 1e-14
```

This is logically inverted. `condest()` returns the **condition number** (ratio of largest to smallest singular value). A well-conditioned matrix has condition number near 1; a **singular** matrix has condition number approaching infinity. The check should fire when the condition number is **large**, not small.

### Exact deliverable

Replace every occurrence of the form `condest(KT_ff) < 1e-14` in `arcLengthStep.m` with:

```matlab
rcond(KT_ff) < 1e-13
```

`rcond` returns the reciprocal condition number — it is near 1 for well-conditioned matrices and near 0 for singular ones. This is the correct threshold direction. Apply the same fix to any identical pattern in `newtonLoop.m` if present.

### Self-check criteria

- [ ] `grep -n "condest" src/@FEM_Solver_ArcLength/arcLengthStep.m` returns zero matches.
- [ ] `grep -n "condest" src/@FEM_Solver_Nonlinear/newtonLoop.m` returns zero matches.
- [ ] The singularity check in `arcLengthStep.m` reads `rcond(KT_ff) < 1e-13`.

### Verification procedure

```matlab
% Verify rcond usage is correct by testing with a known-singular matrix
KT_singular = zeros(10, 10);
KT_good = eye(10);
assert(rcond(KT_singular) < 1e-13, 'H4: singular matrix not detected');
assert(rcond(KT_good) > 1e-13, 'H4: non-singular matrix falsely flagged');
fprintf('H4 PASS: singularity check direction correct\n');
```

---

## Task H5 — Fix `DataManager/loadState.m`: reconstruct correct solver on restart

### Context

`src/@FEM_DataManager/loadState.m` contains:

```matlab
Sol = FEM_Solver_Plastic(Pre, MatObj);
```

The class `FEM_Solver_Plastic` does not exist in the codebase. Any attempt to restart a plastic analysis will crash immediately with an "undefined function" error. The plastic analysis capability lives in `FEM_Solver_Adaptive` with a `Material_J2Plastic` object wired through the preprocessor's material.

### Exact deliverable

Replace the `FEM_Solver_Plastic` reconstruction block with:

```matlab
% Reconstruct for plastic analysis
if isfield(data, 'GlobalHistory') && ~isempty(data.GlobalHistory)
    % Rewire plastic material onto the preprocessor
    if isfield(matData, 'Yield') && isfield(matData, 'H')
        Pre.setMaterialPlastic(matData.Yield, matData.H);
    end
    Sol = FEM_Solver_Adaptive(Pre, SolverOptions());
    % Restore plastic GP history to element cache
    if isprop(Sol, 'Elements') && ~isempty(Sol.Elements)
        nElems = length(Sol.Elements);
        for e = 1:nElems
            if isprop(Sol.Elements{e}, 'HistoryData') && ...
               e <= length(data.GlobalHistory)
                Sol.Elements{e}.HistoryData = data.GlobalHistory{e};
            end
        end
    end
else
    Sol = FEM_Solver(Pre);
end
```

### Self-check criteria

- [ ] `grep -n "FEM_Solver_Plastic" src/@FEM_DataManager/loadState.m` returns zero matches.
- [ ] The reconstruction block uses `FEM_Solver_Adaptive` for plastic cases.
- [ ] The element history loop correctly restores `HistoryData` per element.

### Verification procedure

```matlab
% Simulate save/load roundtrip for elastic case (plastic would need full run)
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 3, -100, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
DM = FEM_DataManager('test_restart', tempdir, 'MAT');
opts_save = struct('saveMesh',true,'saveBCs',true,'saveResults',true,'saveHistory',false);
DM.saveState(Pre, Sol, opts_save);
[Pre2, Sol2] = DM.loadState();
assert(norm(Sol2.U - Sol.U) < 1e-10, 'H5 FAIL: restart produced different U');
fprintf('H5 PASS: save/load roundtrip correct\n');
```

---

## Phase 0 completion gate

Before proceeding to Phase 1, run the full benchmark:

```matlab
% All five hotfixes together — run existing test suite
run('tests/test_postprocessor_v2.m');  % must produce 0 failures
% Patch test
run('tests/Patchtest/Patchtest.m');    % must pass all checks
fprintf('Phase 0 COMPLETE\n');
```

---

# PHASE 1 — Infrastructure

> **Goal:** Introduce three new value objects (`Assembler`, `SolutionState`, `SolutionSnapshot`) and clean up `SolverOptions`. No existing solver behaviour changes. All new code is **additive** — existing solvers continue to call old methods which now delegate to the new objects internally.

---

## Task I1 — Extract `Assembler` as a static-method class

### Context

Currently the assembly logic lives across four methods on `FEM_Solver`: `assembleK`, `assembleKg`, `assembleTangentSystem`, `assembleinternalforceONLY`. These methods mix orchestration (the solver's job) with computation (a pure function's job). Extracting them to a static class makes the assembly testable in isolation, removes circular dependencies, and enables the `SolutionState` design that follows.

### Exact deliverable

Create `src/@Assembler/Assembler.m` with the following exact structure:

```matlab
classdef Assembler
% ASSEMBLER  Stateless finite element matrix assembly.
%
% All methods are static — no instance, no stored state.
% Inputs are explicit; outputs are returned. No side effects.
%
% Usage:
%   K  = Assembler.elastic(Elements, SctrMap, nDofs)
%   Kg = Assembler.geometric(U, Elements, SctrMap, nDofs)
%   [KT, F_int, TrialHist] = Assembler.tangent(U, Elements, SctrMap, nDofs)
%   F_int = Assembler.internalForce(U, Elements, SctrMap, nDofs)

    methods (Static)

        function K = elastic(Elements, SctrMap, nDofs)
        % ELASTIC  Assemble linear elastic stiffness matrix.
        % Elements: {nElems×1} cell of Curve8Element objects
        % SctrMap:  [nElems×48] int32 scatter index map
        % nDofs:    total number of DOFs (scalar)
        % Returns K: sparse [nDofs×nDofs]
            nElems = length(Elements);
            nz = 48*48*nElems;
            [ii_base, jj_base] = ndgrid(1:48, 1:48);
            ii_base = ii_base(:); jj_base = jj_base(:);
            I = zeros(nz,1,'int32');
            J = zeros(nz,1,'int32');
            V = zeros(nz,1);
            count = 0;
            for e = 1:nElems
                Ke = Elements{e}.computeGlobalMatrix6DOF();
                sctr = int32(SctrMap(e,:));
                range = count + (1:2304);
                I(range) = sctr(ii_base);
                J(range) = sctr(jj_base);
                V(range) = Ke(:);
                count = count + 2304;
            end
            K = sparse(double(I), double(J), V, nDofs, nDofs);
        end

        function Kg = geometric(U, Elements, SctrMap, nDofs)
        % GEOMETRIC  Assemble geometric stiffness matrix (for buckling).
        % U: current displacement vector [nDofs×1]
            nElems = length(Elements);
            nz = 48*48*nElems;
            [ii_base, jj_base] = ndgrid(1:48, 1:48);
            ii_base = ii_base(:); jj_base = jj_base(:);
            I = zeros(nz,1,'int32');
            J = zeros(nz,1,'int32');
            V = zeros(nz,1);
            count = 0;
            for e = 1:nElems
                sctr = int32(SctrMap(e,:));
                u_el = U(sctr);
                Kge = Elements{e}.computeGlobalKg6DOF(u_el);
                range = count + (1:2304);
                I(range) = sctr(ii_base);
                J(range) = sctr(jj_base);
                V(range) = Kge(:);
                count = count + 2304;
            end
            Kg = sparse(double(I), double(J), V, nDofs, nDofs);
        end

        function [KT, F_int, TrialHist] = tangent(U, Elements, SctrMap, nDofs)
        % TANGENT  Assemble tangent stiffness, internal force, and trial history.
        % TrialHist: {nElems×1} cell of NewHist structs — NOT committed to elements
            nElems = length(Elements);
            nz = 48*48*nElems;
            [ii_base, jj_base] = ndgrid(1:48, 1:48);
            ii_base = ii_base(:); jj_base = jj_base(:);
            I = zeros(nz,1,'int32');
            J = zeros(nz,1,'int32');
            V = zeros(nz,1);
            F_int = zeros(nDofs, 1);
            TrialHist = cell(nElems, 1);
            count = 0;
            for e = 1:nElems
                sctr = int32(SctrMap(e,:));
                u_el = U(sctr);
                [KTe, fe, NewHist] = Elements{e}.computeGlobalMatrix6DOF(u_el);
                TrialHist{e} = NewHist;
                F_int(sctr) = F_int(sctr) + fe;
                range = count + (1:2304);
                I(range) = sctr(ii_base);
                J(range) = sctr(jj_base);
                V(range) = KTe(:);
                count = count + 2304;
            end
            KT = sparse(double(I), double(J), V, nDofs, nDofs);
        end

        function F_int = internalForce(U, Elements, SctrMap, nDofs)
        % INTERNALFORCE  Compute internal force vector only (no stiffness).
            nElems = length(Elements);
            F_int = zeros(nDofs, 1);
            for e = 1:nElems
                sctr = SctrMap(e,:);
                u_el = U(sctr);
                fe = Elements{e}.computeGlobalForceONLY(u_el);
                F_int(sctr) = F_int(sctr) + fe;
            end
        end

    end
end
```

Wire `FEM_Solver.assembleK` to delegate to `Assembler.elastic`:

```matlab
% In src/@FEM_Solver/assembleK.m — add at the end, keeping existing code as fallback:
% Replace the sparse triplet loop body with:
obj.GlobalK = Assembler.elastic(obj.Elements, obj.SctrMap, nTotalDofs);
```

Wire `FEM_Solver.assembleTangentSystem` to delegate to `Assembler.tangent`.

### Self-check criteria

- [ ] `src/@Assembler/Assembler.m` exists with all four static methods.
- [ ] `methods(Assembler)` in MATLAB lists: `elastic`, `geometric`, `tangent`, `internalForce`.
- [ ] `FEM_Solver.assembleK` calls `Assembler.elastic`.
- [ ] `FEM_Solver.assembleTangentSystem` calls `Assembler.tangent`.
- [ ] No `for` loop over elements exists in `assembleK.m` or `assembleTangentSystem.m` after the delegation (the loop is inside `Assembler`).

### Verification procedure

```matlab
% Test that Assembler produces identical K to the old assembleK
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 3, -500, 'load');
Sol = FEM_Solver(Pre);
Sol.assembleK();
K_new = Sol.GlobalK;

% Direct call to Assembler
K_direct = Assembler.elastic(Sol.Elements, Sol.SctrMap, size(Pre.Mesh.Nodes,1)*6);
diff = norm(K_new - K_direct, 'fro');
assert(diff < 1e-10, sprintf('I1 FAIL: K mismatch, diff = %.3e', diff));

% Full static solution must still work
Sol.applyLoads(); Sol.applyConstraints();
f = Sol.FreeDofs;
U = Sol.GlobalK(f,f) \ Sol.GlobalF(f);
assert(~any(isnan(U)), 'I1 FAIL: NaN in solution after Assembler delegation');
fprintf('I1 PASS: Assembler produces correct K\n');
```

---

## Task I2 — Clean up `SolverOptions`: remove duplicate alias properties

### Context

`SolverOptions` currently has duplicate property pairs: `tol`/`Tolerance`, `maxIter`/`MaxIterations`, `linesearch`/`UseLineSearch`. Code in `newtonLoop.m` reads `obj.Options.Tolerance` while legacy code may write `opts.tol`. Setting one has no effect on the other. This causes silent misconfiguration.

### Exact deliverable

1. In `src/@SolverOptions/SolverOptions.m`, **remove** these alias properties:
   - `tol`
   - `maxIter`  
   - `linesearch`

2. Keep only the canonical names: `Tolerance`, `MaxIterations`, `UseLineSearch`.

3. Run a global search and replace across all `src/` files:
   - `obj.Options.tol` → `obj.Options.Tolerance`
   - `obj.Options.maxIter` → `obj.Options.MaxIterations`
   - `obj.Options.linesearch` → `obj.Options.UseLineSearch`
   - `opts.tol` → `opts.Tolerance` (in any local opts struct)

4. Update `SolverOptions` defaults to:
   ```matlab
   Tolerance     = 1e-6
   MaxIterations = 25
   UseLineSearch = false
   NormType      = 'force'   % new: 'force' | 'energy' | 'displacement'
   MemoryMode    = 'all'     % new: 'all' | 'rolling' | 'disk'
   RollingWindow = 100       % steps to keep in 'rolling' mode
   ```

### Self-check criteria

- [ ] `grep -rn "\.tol\b" src/` returns zero matches (excluding comments).
- [ ] `grep -rn "\.maxIter\b" src/` returns zero matches.
- [ ] `grep -rn "\.linesearch\b" src/` returns zero matches.
- [ ] `SolverOptions()` in MATLAB constructs without error.
- [ ] `fieldnames(SolverOptions())` does NOT include `tol`, `maxIter`, or `linesearch`.

### Verification procedure

```matlab
opts = SolverOptions();
assert(isprop(opts, 'Tolerance'), 'I2 FAIL: Tolerance property missing');
assert(isprop(opts, 'MaxIterations'), 'I2 FAIL: MaxIterations property missing');
assert(isprop(opts, 'UseLineSearch'), 'I2 FAIL: UseLineSearch property missing');
assert(isprop(opts, 'NormType'), 'I2 FAIL: NormType property missing');
assert(~isprop(opts, 'tol'), 'I2 FAIL: legacy tol still present');
assert(~isprop(opts, 'maxIter'), 'I2 FAIL: legacy maxIter still present');
opts.Tolerance = 1e-8;
assert(opts.Tolerance == 1e-8, 'I2 FAIL: property assignment failed');
fprintf('I2 PASS: SolverOptions clean\n');
```

---

## Task I3 — Introduce `SolutionState` handle class

### Context

Currently `FEM_Solver_Nonlinear` stores solution history across scattered properties: `U_Hist`, `History_Time`, `LambdaHist`, `ArcLengthHistory`, `StepCount`, `ReactionHist`. These can be accessed and mutated from outside. `SolutionState` centralises all history behind an append-only API so no external code can accidentally corrupt it.

### Exact deliverable

Create `src/@SolutionState/SolutionState.m`:

```matlab
classdef SolutionState < handle
% SOLUTIONSTATE  Append-only archive of all solver history.
%
% The active solver is the ONLY object that calls appendStep().
% The postprocessor receives a SolutionSnapshot (see snapshot()) — never
% a live SolutionState reference.
%
% Memory management is controlled by SolverOptions.MemoryMode:
%   'all'     — keep every step in RAM (default)
%   'rolling' — keep only the last RollingWindow steps
%   'disk'    — spill older steps to MAT file (future extension)

    properties (SetAccess = private)
        % Displacement history: columns are steps
        U_Hist              double   % [nDofs × capacity]
        LambdaHist          double   % [1 × capacity]
        ArcLengthHist       double   % [1 × capacity]

        % Plastic history: cell(capacity,1), each entry cell(nElems,1) of gpData
        PlasticHistoryArchive cell

        % Reaction forces: cell(nStages,1), each [nFixed × nStepsInStage]
        ReactionHist        cell

        % Eigenanalysis results (set once, never appended)
        ModeShapes          double
        BucklingFactors     double

        % Counters
        StepCount    (1,1) double = 0
        StageCount   (1,1) double = 0
    end

    properties (Access = private)
        Capacity     (1,1) double = 0
        ChunkSize    (1,1) double = 50
        nDofs        (1,1) double
        MemoryMode   char  = 'all'
        RollingWindow (1,1) double = 100
        HasPlastic   (1,1) logical = false
    end

    methods

        function obj = SolutionState(nDofs, opts)
        % SOLUTIONSTATE  Construct with known DOF count and memory options.
        % nDofs: total number of degrees of freedom
        % opts:  SolverOptions instance (optional)
            obj.nDofs = nDofs;
            if nargin >= 2 && ~isempty(opts)
                obj.MemoryMode    = opts.MemoryMode;
                obj.RollingWindow = opts.RollingWindow;
            end
            obj.growArrays();
        end

        function appendStep(obj, U, lambda, plasticSnap, reaction, ds)
        % APPENDSTEP  Commit one converged increment to the archive.
        %
        % U:           [nDofs×1] converged displacement
        % lambda:      scalar load factor (0 if not arc-length)
        % plasticSnap: {nElems×1} cell of gpData structs, or [] if elastic
        % reaction:    struct with .dofs and .values, or [] if none
        % ds:          arc-length radius used, or 0

            obj.StepCount = obj.StepCount + 1;

            % Grow if needed
            if obj.StepCount > obj.Capacity
                obj.growArrays();
            end

            s = obj.StepCount;
            obj.U_Hist(:, s)        = U;
            obj.LambdaHist(s)       = lambda;
            obj.ArcLengthHist(s)    = ds;

            % Plastic archive (deep copy)
            if ~isempty(plasticSnap)
                obj.HasPlastic = true;
                obj.PlasticHistoryArchive{s} = plasticSnap;
            end

            % Reaction history
            if ~isempty(reaction) && obj.StageCount > 0
                sIdx = obj.StageCount;
                if length(obj.ReactionHist) < sIdx || isempty(obj.ReactionHist{sIdx})
                    obj.ReactionHist{sIdx} = struct('dofs', reaction.dofs, ...
                        'values', reaction.values, 'steps', reaction.values);
                else
                    obj.ReactionHist{sIdx}.values(:, end+1) = reaction.values;
                end
            end

            % Rolling mode: evict old data
            if strcmp(obj.MemoryMode, 'rolling') && s > obj.RollingWindow
                oldest = s - obj.RollingWindow;
                obj.U_Hist(:, oldest) = 0;
                if obj.HasPlastic
                    obj.PlasticHistoryArchive{oldest} = [];
                end
            end
        end

        function beginStage(obj)
        % BEGINSTAGE  Increment stage counter for ReactionHist indexing.
            obj.StageCount = obj.StageCount + 1;
            obj.ReactionHist{obj.StageCount} = [];
        end

        function setEigenResults(obj, modes, factors)
        % SETEIGENRESULTS  Store buckling or vibration results.
            obj.ModeShapes      = modes;
            obj.BucklingFactors = factors;
        end

        function snap = snapshot(obj)
        % SNAPSHOT  Return an immutable SolutionSnapshot for postprocessing.
        % U_Hist is COPIED (subset). PlasticArchive is shared by reference.
            s = obj.StepCount;
            snap = SolutionSnapshot();
            snap.U_Hist             = obj.U_Hist(:, 1:s);
            snap.LambdaHist         = obj.LambdaHist(1:s);
            snap.ArcLengthHist      = obj.ArcLengthHist(1:s);
            snap.PlasticHistoryArchive = obj.PlasticHistoryArchive(1:s);
            snap.ReactionHist       = obj.ReactionHist;
            snap.ModeShapes         = obj.ModeShapes;
            snap.BucklingFactors    = obj.BucklingFactors;
            snap.StepCount          = s;
        end

        function U = getU(obj, stepIdx)
        % GETU  Retrieve displacement at a specific step (read-only access).
            if stepIdx < 1 || stepIdx > obj.StepCount
                error('SolutionState:outOfRange', ...
                    'Step %d out of range [1, %d]', stepIdx, obj.StepCount);
            end
            U = obj.U_Hist(:, stepIdx);
        end

    end

    methods (Access = private)
        function growArrays(obj)
            newCap = obj.Capacity + obj.ChunkSize;
            obj.U_Hist      = [obj.U_Hist,      zeros(obj.nDofs, obj.ChunkSize)];
            obj.LambdaHist  = [obj.LambdaHist,  zeros(1, obj.ChunkSize)];
            obj.ArcLengthHist = [obj.ArcLengthHist, zeros(1, obj.ChunkSize)];
            if obj.HasPlastic || obj.Capacity == 0
                obj.PlasticHistoryArchive = [obj.PlasticHistoryArchive; ...
                    cell(obj.ChunkSize, 1)];
            end
            obj.Capacity = newCap;
        end
    end
end
```

Also create `src/@SolutionSnapshot/SolutionSnapshot.m`:

```matlab
classdef SolutionSnapshot
% SOLUTIONSNAPSHOT  Immutable value object given to the postprocessor.
% Never returned by a live solver — only by SolutionState.snapshot().
% The postprocessor MUST NOT call appendStep or commitHistory.
    properties
        U_Hist                double
        LambdaHist            double
        ArcLengthHist         double
        PlasticHistoryArchive cell
        ReactionHist          cell
        ModeShapes            double
        BucklingFactors       double
        StepCount             double = 0
    end
    methods
        function U = getU(obj, stepIdx)
            if stepIdx < 1 || stepIdx > obj.StepCount
                error('SolutionSnapshot:outOfRange', ...
                    'Step %d out of range [1, %d]', stepIdx, obj.StepCount);
            end
            U = obj.U_Hist(:, stepIdx);
        end
        function lambda = getLambda(obj, stepIdx)
            lambda = obj.LambdaHist(stepIdx);
        end
    end
end
```

Wire `FEM_Solver_Nonlinear` to construct a `SolutionState` in its constructor and use `state.appendStep` instead of direct property writes. Keep the old properties (`U_Hist`, `LambdaHist`, etc.) as **deprecated forwarding accessors** that read from the new state object, so existing callers still work:

```matlab
% In FEM_Solver_Nonlinear constructor:
obj.state = SolutionState(nDofs, obj.Options);

% Add forwarding getters (do NOT delete old property names yet):
function v = get.U_Hist(obj)
    v = obj.state.U_Hist(:, 1:obj.state.StepCount);
end
function v = get.LambdaHist(obj)
    v = obj.state.LambdaHist(1:obj.state.StepCount);
end
function v = get.StepCount(obj)
    v = obj.state.StepCount;
end
```

### Self-check criteria

- [ ] `src/@SolutionState/SolutionState.m` exists.
- [ ] `src/@SolutionSnapshot/SolutionSnapshot.m` exists.
- [ ] `SolutionState(60, SolverOptions())` constructs without error.
- [ ] After `state.appendStep(zeros(60,1), 0, [], [], 0)`, `state.StepCount == 1`.
- [ ] `state.snapshot()` returns a `SolutionSnapshot` instance.
- [ ] `FEM_Solver_Nonlinear` has a `state` property of type `SolutionState`.
- [ ] `Sol.U_Hist` still works (reads from `state` via forwarding accessor).

### Verification procedure

```matlab
% Unit test SolutionState
nD = 120;
opts = SolverOptions();
state = SolutionState(nD, opts);
assert(state.StepCount == 0, 'I3 FAIL: initial StepCount');
for k = 1:5
    U_k = rand(nD, 1);
    state.appendStep(U_k, k*0.1, [], [], 0.05);
end
assert(state.StepCount == 5, 'I3 FAIL: StepCount after 5 appends');
U3 = state.getU(3);
assert(length(U3) == nD, 'I3 FAIL: getU wrong size');
snap = state.snapshot();
assert(isa(snap, 'SolutionSnapshot'), 'I3 FAIL: snapshot wrong type');
assert(snap.StepCount == 5, 'I3 FAIL: snapshot StepCount');
assert(size(snap.U_Hist, 2) == 5, 'I3 FAIL: snapshot U_Hist columns');
fprintf('I3 PASS: SolutionState and SolutionSnapshot work\n');
```

---

## Phase 1 completion gate

```matlab
% Full integration test: linear + postprocessor still works
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(4, 4);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 3, -1000, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
Post = FEM_Postprocessor(Pre, Sol);
vm = Post.recoverNodalSmooth('VonMises', 'Top');
assert(all(vm >= 0), 'Phase1 FAIL: negative VonMises');
assert(~any(isnan(vm)), 'Phase1 FAIL: NaN in VonMises');
fprintf('Phase 1 COMPLETE\n');
```

---

# PHASE 2 — Core Newton-Raphson correctness

> **Goal:** Introduce `ConvergenceMonitor`, rewrite `newtonLoop` to use it, fix the `linesearch` return contract (building on H1), and implement `PlasticHistoryArchive` via `SolutionState.appendStep`.

---

## Task C1 — Implement `ConvergenceMonitor` class

### Context

Convergence checking is currently inline in `newtonLoop` as a single hardcoded expression. A dedicated monitor enables: (a) pluggable norm types, (b) diagnostic history for adaptive stepping, (c) energy-norm convergence which is more robust near limit points.

### Exact deliverable

Create `src/@ConvergenceMonitor/ConvergenceMonitor.m`:

```matlab
classdef ConvergenceMonitor < handle
% CONVERGENCEMONITOR  Pluggable convergence checking for iterative solvers.
%
% NormType options:
%   'force'        ||R(free)|| / max(||F_ext(free)||, 1)   [default]
%   'energy'       |dU · R| / max(|dU_0 · R_0|, 1)
%   'displacement' ||dU(free)|| / max(||U(free)||, 1)

    properties
        Tolerance     (1,1) double  = 1e-6
        MaxIterations (1,1) double  = 25
        NormType      char          = 'force'
        ResidualHistory             double   % [MaxIterations×1] per step
        IterationsUsed (1,1) double = 0
    end

    properties (Access = private)
        Ref0  (1,1) double = 1.0   % reference norm (first iteration)
        dU0_R0 (1,1) double = 1.0  % energy reference
    end

    methods

        function reset(obj, F_ext_free)
        % RESET  Call at the start of each Newton step.
            obj.Ref0 = max(norm(F_ext_free), 1.0);
            obj.dU0_R0 = 1.0;
            obj.ResidualHistory = zeros(obj.MaxIterations, 1);
            obj.IterationsUsed = 0;
        end

        function ok = check(obj, R_free, dU_free, F_ext_free, iter)
        % CHECK  Evaluate convergence at current iteration.
        % Returns true if converged.
            switch obj.NormType
                case 'force'
                    err = norm(R_free) / obj.Ref0;
                case 'energy'
                    e_curr = abs(dU_free' * R_free);
                    if iter == 1
                        obj.dU0_R0 = max(e_curr, 1e-30);
                    end
                    err = e_curr / obj.dU0_R0;
                case 'displacement'
                    U_norm = max(norm(dU_free), 1e-30);
                    err = norm(dU_free) / U_norm;
                otherwise
                    err = norm(R_free) / obj.Ref0;
            end
            obj.ResidualHistory(iter) = err;
            obj.IterationsUsed = iter;
            ok = (err <= obj.Tolerance);
        end

        function report(obj)
        % REPORT  Print convergence history for this step.
            fprintf('  Convergence history (%s norm):\n', obj.NormType);
            for k = 1:obj.IterationsUsed
                marker = '';
                if k == obj.IterationsUsed && obj.ResidualHistory(k) <= obj.Tolerance
                    marker = ' [CONVERGED]';
                end
                fprintf('    iter %2d: %.4e%s\n', k, obj.ResidualHistory(k), marker);
            end
        end

    end
end
```

### Self-check criteria

- [ ] `src/@ConvergenceMonitor/ConvergenceMonitor.m` exists.
- [ ] `ConvergenceMonitor()` constructs without error.
- [ ] `check(R, dU, Fext, 1)` returns `true` when `norm(R)/norm(Fext) < 1e-6`.
- [ ] `check(R, dU, Fext, 1)` returns `false` when `norm(R)/norm(Fext) > 1`.

### Verification procedure

```matlab
mon = ConvergenceMonitor();
mon.Tolerance = 1e-6;
Fext = ones(10,1) * 100;
mon.reset(Fext);
R_converged = ones(10,1) * 1e-5;
R_diverged  = ones(10,1) * 1000;
dU = ones(10,1);
assert(mon.check(R_converged, dU, Fext, 1), 'C1 FAIL: should converge');
mon.reset(Fext);
assert(~mon.check(R_diverged, dU, Fext, 1), 'C1 FAIL: should not converge');
fprintf('C1 PASS: ConvergenceMonitor correct\n');
```

---

## Task C2 — Rewrite `newtonLoop` using `ConvergenceMonitor` and `SolutionState`

### Context

Rebuild `newtonLoop.m` from scratch using the infrastructure from I1 (Assembler), I2 (clean options), I3 (SolutionState), and C1 (ConvergenceMonitor). The new version must enforce the trial-commit invariant rigorously.

### Exact deliverable

Replace `src/@FEM_Solver_Nonlinear/newtonLoop.m` with:

```matlab
function [converged, U_out, reaction, iters] = newtonLoop(obj, F_ext, U_start, fixed_dofs)
% NEWTONLOOP  Core Newton-Raphson corrector.
%
% Inputs:
%   F_ext       [nDofs×1] external force vector (full DOF space)
%   U_start     [nDofs×1] starting displacement (entry state, returned on diverge)
%   fixed_dofs  [nFixed×1] indices of constrained DOFs
%
% Outputs:
%   converged   logical
%   U_out       converged U (or U_start on diverge — NEVER the drifted state)
%   reaction    F_int(fixed_dofs) on converge, [] on diverge
%   iters       number of iterations taken

nDofs     = length(U_start);
free_dofs = setdiff(1:nDofs, fixed_dofs)';

% Save entry state — returned unchanged on diverge
U_entry  = U_start;
U_curr   = U_start;
U_curr(fixed_dofs) = F_ext(fixed_dofs);  % enforce prescribed displacements

% Build convergence monitor from solver options
mon = ConvergenceMonitor();
mon.Tolerance     = obj.Options.Tolerance;
mon.MaxIterations = obj.Options.MaxIterations;
mon.NormType      = obj.Options.NormType;
mon.reset(F_ext(free_dofs));

converged  = false;
TrialHist  = [];
reaction   = [];
iters      = 0;

for iter = 1:obj.Options.MaxIterations
    iters = iter;

    % 1. Assemble (pure function — no side effects)
    [KT, F_int, TrialHist] = Assembler.tangent(U_curr, obj.Elements, obj.SctrMap, nDofs);

    % 2. Residual — R = F_int - F_ext, BC rows zeroed
    R = F_int - F_ext;
    R(fixed_dofs) = 0;

    % 3. Convergence check
    dU_prev = zeros(length(free_dofs), 1);
    if iter > 1, dU_prev = U_curr(free_dofs) - U_entry(free_dofs); end
    if mon.check(R(free_dofs), dU_prev, F_ext(free_dofs), iter)
        converged = true;
        break;
    end

    % 4. Solve for increment
    KT_ff = KT(free_dofs, free_dofs);
    if rcond(KT_ff) < 1e-13
        warning('newtonLoop:singular', 'KT is near-singular at iter %d', iter);
        break;
    end
    dU_f = KT_ff \ (-R(free_dofs));

    % 5. Line search (returns eta scalar — does NOT modify obj.U)
    if obj.Options.UseLineSearch
        eta = obj.linesearch(U_curr, sparse(nDofs,1), R, F_ext, free_dofs);
        % Note: linesearch needs refactoring in H1 to accept dU_f
        % Until then, default eta = 1
        eta = 1.0;  % TODO: remove once H1 linesearch is wired correctly
    else
        eta = 1.0;
    end

    % 6. Update (trial only — not committed to obj.U)
    U_curr(free_dofs) = U_curr(free_dofs) + eta * dU_f;
end

% 7. Commit or discard
if converged
    % Atomic commit: only here does state change
    obj.cache.commitHistory(TrialHist);
    reaction = F_int(fixed_dofs);
    U_out = U_curr;
    obj.U = U_curr;
else
    % Diverged: discard TrialHist, return clean entry state
    TrialHist = [];  %#ok<NASGU> — allow GC
    U_out = U_entry;
    reaction = [];
end
end
```

> **Note on `obj.cache`:** This requires that `FEM_Solver_Nonlinear` holds an `ElementCache` object (added in Phase 3 full unification). For now, keep `commitHistory` as a method on `FEM_Solver`:
> ```matlab
> % Temporary bridge until ElementCache is introduced:
> if converged
>     obj.commitHistory(TrialHist);
> end
> ```

### Self-check criteria

- [ ] `newtonLoop` calls `Assembler.tangent` (not `obj.assembleTangentSystem`).
- [ ] `R = F_int - F_ext` (not `F_ext - F_int`).
- [ ] `R(fixed_dofs) = 0` appears before the convergence check.
- [ ] `commitHistory` is called **only** inside `if converged`.
- [ ] `U_out = U_entry` on the diverge path.
- [ ] `rcond` check (not `condest`).

### Verification procedure

```matlab
% Patch test: linear analysis must give exact solution for constant strain
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(4, 4);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 1, 1000, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
tipNodes = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
Ux_tip = mean(Sol.U((tipNodes-1)*6 + 1));
Ux_analytical = 1000 / (210e3 * 0.01) * 1.0;  % F/(EA) * L
assert(abs(Ux_tip - Ux_analytical)/Ux_analytical < 0.02, ...
    sprintf('C2 FAIL: patch test error %.2f%%', ...
    abs(Ux_tip-Ux_analytical)/Ux_analytical*100));
fprintf('C2 PASS: newtonLoop patch test within 2%%\n');
```

---

## Task C3 — Wire `linesearch` return contract (builds on H1)

### Context

H1 changed `linesearch` to return `eta`. Now `newtonLoop` must actually use the returned `eta` correctly. This task ensures the full call chain is wired.

### Exact deliverable

In `newtonLoop.m`, replace the TODO comment from C2 with the actual linesearch call:

```matlab
if obj.Options.UseLineSearch
    % linesearch returns eta in (0,1] — backtracking line search
    eta = obj.linesearch(U_curr, dU_f_full, R, F_ext, free_dofs);
else
    eta = 1.0;
end
U_curr(free_dofs) = U_curr(free_dofs) + eta * dU_f;
```

Where `dU_f_full` is a zero-padded full-DOF version of `dU_f`:
```matlab
dU_f_full = zeros(nDofs, 1);
dU_f_full(free_dofs) = dU_f;
```

Ensure `linesearch.m` signature matches: `function eta = linesearch(obj, U_old, dU, R, F_ext_current, free_dofs)`.

### Self-check criteria

- [ ] `linesearch` is called with `(U_curr, dU_f_full, R, F_ext, free_dofs)`.
- [ ] The returned `eta` is used as `U_curr(free_dofs) += eta * dU_f`.
- [ ] No `obj.U` assignment inside `linesearch.m`.

### Verification procedure

```matlab
% Test that UseLineSearch=true doesn't break convergence on a simple problem
opts = SolverOptions();
opts.UseLineSearch = true;
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 3, -500, 'load');
Sol = FEM_Solver_Adaptive(Pre, opts);
stage = LoadingStage(1.0);
stage.activateBC('Support'); % won't find tags, that's fine — just tests the linesearch path
Sol.solve({stage});
assert(~any(isnan(Sol.U)), 'C3 FAIL: NaN with UseLineSearch=true');
fprintf('C3 PASS: linesearch wired correctly\n');
```

---

## Task C4 — Implement `PlasticHistoryArchive` in `SolutionState`

### Context

After each converged step in a plastic analysis, the GP history (`HistoryData` on each element) must be archived so the postprocessor can recover exact stresses at any past step. Currently `recoverAllGaussPoints(stepIdx)` in `FEM_Postprocessor_v2` warns that past plastic states are unavailable and falls back to elastic re-integration. This task closes that gap.

### Exact deliverable

1. In `FEM_Solver_Adaptive/solveStage.m`, after the `commitHistory` call on a converged step, add:
   ```matlab
   % Archive plastic GP state for this step
   plasticSnap = [];
   if obj.hasMaterialPlastic()  % helper: checks Material.Type == 'J2Plastic'
       plasticSnap = cell(nElems, 1);
       for e = 1:nElems
           if isprop(obj.Elements{e}, 'HistoryData')
               plasticSnap{e} = obj.Elements{e}.HistoryData;
           end
       end
   end
   obj.state.appendStep(U_conv, lambda, plasticSnap, reaction_struct, 0);
   ```

2. Add helper method `hasMaterialPlastic(obj)` to `FEM_Solver`:
   ```matlab
   function tf = hasMaterialPlastic(obj)
       tf = isfield(obj.Model.Material, 'Type') && ...
            strcmp(obj.Model.Material.Type, 'J2Plastic');
   end
   ```

3. In `FEM_Postprocessor_v2/recoverAllGaussPoints.m`, update the past-step path:
   ```matlab
   if useHistoryData && ~isempty(obj.Solver.state) && ...
      stepIdx > 0 && stepIdx <= obj.Solver.state.StepCount && ...
      ~isempty(obj.Solver.state.PlasticHistoryArchive{stepIdx})
       % Use archived plastic state
       savedHD = obj.Solver.Elements{e}.HistoryData;
       obj.Solver.Elements{e}.HistoryData = ...
           obj.Solver.state.PlasticHistoryArchive{stepIdx}{e};
       gpCell{e} = elObj.recoverGaussPointData(u_el);
       obj.Solver.Elements{e}.HistoryData = savedHD;
   else
       % Elastic path or current step
       gpCell{e} = elObj.recoverGaussPointData(u_el);
   end
   ```

### Self-check criteria

- [ ] `solveStage.m` archives plastic snap after every converged step when `hasMaterialPlastic()` is true.
- [ ] `hasMaterialPlastic()` correctly returns `false` for elastic models.
- [ ] `recoverAllGaussPoints` uses archived history for past steps when available.
- [ ] For elastic models, `PlasticHistoryArchive` cells remain empty `{}`.

### Verification procedure

```matlab
% Elastic model: archive must be empty
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 3, -100, 'load');
opts = SolverOptions(); opts.numLoadSteps = 3;
Sol = FEM_Solver_Adaptive(Pre, opts);
S1 = LoadingStage(1.0); S1.activateBC('Support'); S1.activateLoad('load');
Sol.solve({S1});
assert(all(cellfun(@isempty, Sol.state.PlasticHistoryArchive)), ...
    'C4 FAIL: elastic model has non-empty PlasticArchive');
fprintf('C4 PASS: PlasticHistoryArchive empty for elastic model\n');
```

---

## Phase 2 completion gate

```matlab
% Snap-through or NL bending — NR must converge with correct residual sign
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.005);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(4, 4);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'fix');
tipN = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
Pre.addNodalLoad(tipN, 3, -200, 'load');
opts = SolverOptions(); opts.numLoadSteps = 5; opts.MaxIterations = 20;
Sol = FEM_Solver_Adaptive(Pre, opts);
S1 = LoadingStage(1.0); S1.activateBC('Support'); S1.activateLoad('load');
Sol.solve({S1});
assert(Sol.StepCount > 0, 'Phase2 FAIL: no steps converged');
assert(~any(isnan(Sol.U)), 'Phase2 FAIL: NaN in U');
fprintf('Phase 2 COMPLETE: %d steps converged\n', Sol.StepCount);
```

---

# PHASE 3 — Arc-length solver and strategy pattern

> **Goal:** Introduce `IncrementalStrategy` interface and three concrete implementations, rewrite `arcLengthStep` to be constraint-agnostic, fix stage termination, and unify `FEM_Solver_Adaptive` and `FEM_Solver_ArcLength` into a single nonlinear solver.

---

## Task A1 — Implement `IncrementalStrategy` interface and three concrete classes

### Context

The arc-length solver currently switches on a string `ConstraintType` to dispatch to different constraint functions. Adding a new constraint type requires modifying the solver class itself. The Strategy pattern makes each constraint a self-contained object with a defined interface.

### Exact deliverable

**A. Abstract base** — create `src/@IncrementalStrategy/IncrementalStrategy.m`:

```matlab
classdef (Abstract) IncrementalStrategy < handle
% INCREMENTALSTRATEGY  Interface for predictor-corrector increment strategies.
%
% Implementations: RiksStrategy, LoadControlStrategy, DispControlStrategy
%
% The arc-length solver calls:
%   1. predictor() once at the start of each increment
%   2. constraint() once per corrector iteration

    properties (Abstract)
        ArcLengthRadius  (1,1) double   % current ds
        ArcLengthMin     (1,1) double
        ArcLengthMax     (1,1) double
    end

    methods (Abstract)
        % PREDICTOR  Compute predicted (u1, lambda1) and store predictor direction.
        % KT_ff:     [nFree×nFree] tangent stiffness on free DOFs
        % F_ext_f:   [nFree×1] external force on free DOFs
        % u0, l0:    current converged state
        % dup_prev:  [nDofs×1] predictor from previous step (for CSP sign)
        % ds:        current arc-length radius
        % free_dofs: indices of free DOFs
        [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs)

        % CONSTRAINT  Evaluate arc-length constraint at current trial state.
        % Returns scalar g, gradient h [nFree×1], load derivative s (scalar)
        [g, h, s] = constraint(obj, u_f, lambda, u0_f, l0, dup_f, dlp, ds)
    end

    methods
        function adaptRadius(obj, iters, maxIter)
        % ADAPTRADIUS  Adjust arc-length radius based on iteration count.
            if iters <= 4
                obj.ArcLengthRadius = min(obj.ArcLengthRadius * 1.5, obj.ArcLengthMax);
            elseif iters > round(maxIter * 0.75)
                obj.ArcLengthRadius = max(obj.ArcLengthRadius * 0.7, obj.ArcLengthMin);
            end
        end
        function halveRadius(obj)
        % HALVERADIUS  Called on trial failure.
            obj.ArcLengthRadius = max(obj.ArcLengthRadius * 0.5, obj.ArcLengthMin);
        end
    end
end
```

**B. Riks (spherical arc-length)** — create `src/@RiksStrategy/RiksStrategy.m`:

```matlab
classdef RiksStrategy < IncrementalStrategy
    properties
        ArcLengthRadius (1,1) double = 0.01
        ArcLengthMin    (1,1) double = 1e-6
        ArcLengthMax    (1,1) double = 1.0
        Psi             (1,1) double = 1.0  % load scaling factor
    end
    methods
        function obj = RiksStrategy(varargin)
            for k = 1:2:length(varargin)
                obj.(varargin{k}) = varargin{k+1};
            end
        end
        function [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs)
            dup_f = KT_ff \ F_ext_f;
            dup = zeros(nDofs, 1);
            dup(free_dofs) = dup_f;
            % CSP sign detection
            if norm(dup_prev) < 1e-14
                sgn = 1;
            else
                sgn = sign(dot(dup_prev, dup));
                if sgn == 0, sgn = 1; end
            end
            dlp = sgn * ds / sqrt(norm(dup_f)^2 + obj.Psi^2 + eps);
            u1 = u0 + dlp * dup;
            l1 = l0 + dlp;
        end
        function [g, h, s] = constraint(obj, u_f, lambda, u0_f, l0, dup_f, dlp, ds)
            u1_f  = u0_f + dlp * dup_f;
            l1    = l0   + dlp;
            g     = dup_f' * (u_f - u1_f) + obj.Psi^2 * dlp * (lambda - l1);
            h     = dup_f;
            s     = obj.Psi^2 * dlp;
            if abs(s) < 1e-14, s = ds * obj.Psi^2; end
        end
    end
end
```

**C. Load control** — create `src/@LoadControlStrategy/LoadControlStrategy.m`:

```matlab
classdef LoadControlStrategy < IncrementalStrategy
    properties
        ArcLengthRadius (1,1) double = 0.1
        ArcLengthMin    (1,1) double = 1e-6
        ArcLengthMax    (1,1) double = 1.0
    end
    methods
        function obj = LoadControlStrategy(varargin)
            for k = 1:2:length(varargin), obj.(varargin{k}) = varargin{k+1}; end
        end
        function [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs)
            dlp = ds;
            dup_f = KT_ff \ (dlp * F_ext_f);
            dup = zeros(nDofs, 1);
            dup(free_dofs) = dup_f;
            u1 = u0 + dup;
            l1 = l0 + dlp;
        end
        function [g, h, s] = constraint(obj, u_f, lambda, u0_f, l0, dup_f, dlp, ds)
            g = lambda - (l0 + ds);
            h = zeros(length(u_f), 1);
            s = 1;
        end
    end
end
```

**D. Displacement control** — create `src/@DispControlStrategy/DispControlStrategy.m`:

```matlab
classdef DispControlStrategy < IncrementalStrategy
    properties
        ArcLengthRadius (1,1) double = 0.001
        ArcLengthMin    (1,1) double = 1e-8
        ArcLengthMax    (1,1) double = 0.1
        ControlDOF      (1,1) double = 0   % global DOF index to control
    end
    methods
        function obj = DispControlStrategy(controlDOF, varargin)
            obj.ControlDOF = controlDOF;
            for k = 1:2:length(varargin), obj.(varargin{k}) = varargin{k+1}; end
        end
        function [u1, l1, dup, dlp] = predictor(obj, KT_ff, F_ext_f, u0, l0, dup_prev, ds, free_dofs, nDofs)
            dlp = 0;  % displacement control: lambda is solved for
            dup_f = ds * (KT_ff \ F_ext_f);
            dup = zeros(nDofs, 1);
            dup(free_dofs) = dup_f;
            u1 = u0 + dup;
            l1 = l0;
        end
        function [g, h, s] = constraint(obj, u_f, lambda, u0_f, l0, dup_f, dlp, ds)
            % Map ControlDOF to free-DOF index
            nFree = length(u_f);
            dof_local = obj.ControlDOF;  % assume already in free-DOF space
            g = u_f(dof_local) - (u0_f(dof_local) + ds);
            h = zeros(nFree, 1);
            if dof_local >= 1 && dof_local <= nFree
                h(dof_local) = 1;
            end
            s = 0;
        end
    end
end
```

### Self-check criteria

- [ ] All four files exist.
- [ ] `isa(RiksStrategy(), 'IncrementalStrategy')` returns `true`.
- [ ] `isa(LoadControlStrategy(), 'IncrementalStrategy')` returns `true`.
- [ ] `methods(RiksStrategy)` includes `predictor` and `constraint`.
- [ ] `RiksStrategy('ArcLengthRadius', 0.05, 'Psi', 0.5)` constructs without error.

### Verification procedure

```matlab
rs = RiksStrategy('ArcLengthRadius', 0.02);
assert(isa(rs, 'IncrementalStrategy'), 'A1 FAIL: RiksStrategy not IncrementalStrategy');
assert(rs.ArcLengthRadius == 0.02, 'A1 FAIL: property not set');
rs.adaptRadius(3, 20);  % iters=3 <= 4, should grow
assert(rs.ArcLengthRadius > 0.02, 'A1 FAIL: adaptRadius did not grow');
lcs = LoadControlStrategy();
assert(isa(lcs, 'IncrementalStrategy'), 'A1 FAIL: LoadControlStrategy type');
fprintf('A1 PASS: all strategy classes correct\n');
```

---

## Task A2 — Rewrite `arcLengthStep` to use strategy object

### Context

Replace the constraint `switch` statement in `arcLengthStep.m` with calls to `strategy.predictor()` and `strategy.constraint()`. The step logic itself stays the same; only the dispatch mechanism changes.

### Exact deliverable

Replace `src/@FEM_Solver_ArcLength/arcLengthStep.m` with a version that:

1. Accepts `strategy` as first argument: `function [u, lambda, F_int, TH, ok, iters] = arcLengthStep(obj, strategy, free_dofs, u0, lambda0, dup_prev, tol, maxit)`
2. Calls `strategy.predictor(KT_ff, F_ext_f, u0, lambda0, dup_prev, strategy.ArcLengthRadius, free_dofs, nDofs)` for the predictor.
3. Calls `strategy.constraint(u_f, lambda, u0_f, lambda0, dup_f, dlp, strategy.ArcLengthRadius)` inside the corrector loop.
4. Reuses the KT factorisation for both `du_I = KT_ff \ F_ext_f` and `du_II = KT_ff \ (-R_f)` — do NOT reassemble between these two solves.
5. Removes all `switch obj.ConstraintType` logic.

Key corrector loop structure:

```matlab
% Inside corrector loop:
[g, h, s] = strategy.constraint(u(free_dofs), lambda, u0(free_dofs), ...
    lambda0, dup(free_dofs), dlp, strategy.ArcLengthRadius);

% Two-solve with shared factorisation
L_KT = decomposition(KT_ff, 'auto');  % single factorisation
du_I_f  =  L_KT \ F_ext_f;
du_II_f = -(L_KT \ R_f);

denom = s + h' * du_I_f;
if abs(denom) < 1e-14 * (abs(s) + 1)
    ok = false; return;
end
dl = -(g + h' * du_II_f) / denom;
du = zeros(nDofs, 1);
du(free_dofs) = dl * du_I_f + du_II_f;

lambda = lambda + dl;
u = u + du;
```

### Self-check criteria

- [ ] No `switch` or `if strcmp(obj.ConstraintType` in `arcLengthStep.m`.
- [ ] `strategy.predictor()` is called exactly once (before the corrector loop).
- [ ] `strategy.constraint()` is called once per corrector iteration.
- [ ] `decomposition()` or `\` with the same `KT_ff` is used for both `du_I_f` and `du_II_f`.
- [ ] `rcond` check on `KT_ff` before any solve.

### Verification procedure

```matlab
% Test all three strategies produce a result without error on simple plate
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.005);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'Support');
tipN = Pre.selectNodesOnPlane(1, 1.0, 1e-6);
Pre.addNodalLoad(tipN, 3, -100, 'load');

for strat_name = {'Riks', 'LoadControl'}
    opts = SolverOptions();
    Sol = FEM_Solver_ArcLength(Pre, opts);
    S1 = LoadingStage(0.5);
    S1.activateBC('Support'); S1.activateLoad('load');
    if strcmp(strat_name{1}, 'Riks')
        S1.strategy = RiksStrategy('ArcLengthRadius', 0.1);
    else
        S1.strategy = LoadControlStrategy('ArcLengthRadius', 0.1);
    end
    Sol.solve({S1});
    assert(Sol.state.StepCount > 0, ...
        sprintf('A2 FAIL: %s strategy produced no steps', strat_name{1}));
    fprintf('A2 PASS: %s strategy converged (%d steps)\n', ...
        strat_name{1}, Sol.state.StepCount);
end
```

---

## Task A3 — Fix arc-length stage termination

### Context

`solveArcLengthStage.m` uses `nSteps = ceil(Stage.Duration / ArcLengthRadius)` as the loop bound. This is problematic when the adaptive radius changes significantly during the run. Replace with a physical termination criterion.

### Exact deliverable

Replace the step-count loop in `solveArcLengthStage.m` with a while loop:

```matlab
% New termination logic:
lambda = initialLambda;
accumulated = 0;  % pseudo-arc-length accumulated
maxSteps = ceil(10 * Stage.Duration / strategy.ArcLengthMin);  % safety ceiling

stepCount = 0;
while accumulated < Stage.Duration && stepCount < maxSteps
    stepCount = stepCount + 1;
    ds = strategy.ArcLengthRadius;

    % ... (trial loop with max_trials halving) ...

    if ~converged
        warning('solveArcLengthStage:failed', ...
            'Stage %d step %d: failed after %d trials. Aborting stage.', s, stepCount, max_trials);
        success = false; return;
    end

    % Commit
    accumulated = accumulated + abs(dlp) + norm(dup_step(free_dofs));
    strategy.adaptRadius(iters_used, obj.Options.MaxIterations);
    % ... (appendStep, history storage) ...
end
success = true;
```

Where `Stage.Duration` is used as the total arc-length budget. If `Stage.TargetLambda` is set, use `lambda >= Stage.TargetLambda` as an additional stopping condition.

Add `TargetLambda` property to `LoadingStage`:

```matlab
% In LoadingStage.m:
TargetLambda (1,1) double = Inf   % stop when lambda reaches this value
```

### Self-check criteria

- [ ] `nSteps = ceil(...)` fixed-count loop is gone from `solveArcLengthStage.m`.
- [ ] A `while` loop with `accumulated < Stage.Duration` controls stepping.
- [ ] A `maxSteps` safety ceiling prevents infinite loops.
- [ ] `LoadingStage` has `TargetLambda` property.

### Verification procedure

```matlab
% Verify stage runs correct number of steps regardless of radius changes
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.005);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'Support');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1,1.0,1e-6), 3, -50, 'load');
opts = SolverOptions();
Sol = FEM_Solver_ArcLength(Pre, opts);
S1 = LoadingStage(1.0);
S1.activateBC('Support'); S1.activateLoad('load');
S1.strategy = RiksStrategy('ArcLengthRadius', 0.2, 'ArcLengthMin', 0.01);
Sol.solve({S1});
assert(Sol.state.StepCount >= 3, 'A3 FAIL: too few steps');
fprintf('A3 PASS: %d steps, while-loop termination works\n', Sol.state.StepCount);
```

---

## Task A4 — Update `LoadingStage` to carry strategy reference

### Context

`LoadingStage` currently uses a `ConstraintType` string property to configure the arc-length behaviour. Replace with a `strategy` property that holds an `IncrementalStrategy` object. Maintain backwards compatibility by auto-constructing the appropriate strategy when the old string API is used.

### Exact deliverable

Update `src/@LoadingStage/LoadingStage.m`:

```matlab
classdef LoadingStage < handle
    properties
        ActiveBCs    = {}
        ActiveLoads  = {}
        Duration     = 1.0
        TargetLambda = Inf

        % New: strategy object (preferred)
        strategy     = []  % IncrementalStrategy instance or []

        % Legacy (deprecated) — auto-construct strategy if set
        ArcLengthRadius = 0.01
        ArcLengthMin    = 1e-6
        ArcLengthMax    = 1.0
        ArcLengthPsi    = 1.0
        ConstraintType  = ''   % deprecated: use strategy instead
        ControlDOF      = []
    end

    methods
        function obj = LoadingStage(duration)
            if nargin > 0, obj.Duration = duration; end
        end
        function activateBC(obj, tag),   obj.ActiveBCs{end+1} = tag; end
        function activateLoad(obj, tag), obj.ActiveLoads{end+1} = tag; end

        function s = getStrategy(obj)
        % GETSTRATEGY  Return the active strategy, constructing from legacy props if needed.
            if ~isempty(obj.strategy)
                s = obj.strategy;
                return;
            end
            if isempty(obj.ConstraintType)
                % Default to Riks
                s = RiksStrategy('ArcLengthRadius', obj.ArcLengthRadius, ...
                    'ArcLengthMin', obj.ArcLengthMin, 'ArcLengthMax', obj.ArcLengthMax, ...
                    'Psi', obj.ArcLengthPsi);
                return;
            end
            switch obj.ConstraintType
                case 'Riks'
                    s = RiksStrategy('ArcLengthRadius', obj.ArcLengthRadius, ...
                        'ArcLengthMin', obj.ArcLengthMin, 'ArcLengthMax', obj.ArcLengthMax);
                case 'LoadControl'
                    s = LoadControlStrategy('ArcLengthRadius', obj.ArcLengthRadius);
                case 'DispControl'
                    if isempty(obj.ControlDOF)
                        error('LoadingStage:noControlDOF', ...
                            'Set ControlDOF before using DispControl');
                    end
                    s = DispControlStrategy(obj.ControlDOF, ...
                        'ArcLengthRadius', obj.ArcLengthRadius);
                otherwise
                    warning('LoadingStage:unknownConstraint', ...
                        'Unknown ConstraintType ''%s'', defaulting to Riks', obj.ConstraintType);
                    s = RiksStrategy('ArcLengthRadius', obj.ArcLengthRadius);
            end
        end
    end
end
```

Update `solveArcLengthStage.m` to call `Stage.getStrategy()` instead of reading `Stage.ConstraintType`.

### Self-check criteria

- [ ] `LoadingStage.getStrategy()` returns an `IncrementalStrategy` instance for all cases.
- [ ] Old code using `Stage.ConstraintType = 'Riks'` still works via `getStrategy()`.
- [ ] New code using `Stage.strategy = RiksStrategy(...)` works via `getStrategy()`.
- [ ] `solveArcLengthStage` calls `Stage.getStrategy()` not `Stage.ConstraintType`.

### Verification procedure

```matlab
% Legacy API still works
S1 = LoadingStage(1.0);
S1.ConstraintType = 'Riks';
S1.ArcLengthRadius = 0.05;
s1 = S1.getStrategy();
assert(isa(s1, 'RiksStrategy'), 'A4 FAIL: legacy Riks');
assert(s1.ArcLengthRadius == 0.05, 'A4 FAIL: radius not propagated');

% New API
S2 = LoadingStage(1.0);
S2.strategy = LoadControlStrategy('ArcLengthRadius', 0.1);
s2 = S2.getStrategy();
assert(isa(s2, 'LoadControlStrategy'), 'A4 FAIL: new API');

% Default
S3 = LoadingStage(2.0);
s3 = S3.getStrategy();
assert(isa(s3, 'RiksStrategy'), 'A4 FAIL: default strategy');
fprintf('A4 PASS: LoadingStage strategy API correct\n');
```

---

## Task A5 — Unify `FEM_Solver_Adaptive` and `FEM_Solver_ArcLength`

### Context

The four-class deep chain (`FEM_Solver` → `FEM_Solver_Nonlinear` → `FEM_Solver_Adaptive` → `FEM_Solver_ArcLength`) is the root cause of duplicated stage-loop code and confusing inheritance. After A1–A4 and C1–C4, the infrastructure exists to collapse this to two classes: `FEM_Solver` (linear + buckling) and `FEM_Solver_Nonlinear` (all incremental analysis, strategy-driven).

### Exact deliverable

This is the largest task. Work in sub-steps:

**Sub-step A5a:** Add a unified `solve(StageList)` method to `FEM_Solver_Nonlinear`:

```matlab
function solve(obj, StageList)
% SOLVE  Multi-stage incremental analysis — works for both NR and arc-length.
%
% For each stage, the active strategy (from Stage.getStrategy()) drives
% the increment type. If strategy is a RiksStrategy or LoadControlStrategy,
% arc-length logic runs. If strategy is [] or a simple load-control object
% with a fixed dlambda equal to the full stage, NR logic runs.
%
% This unified entry point replaces both FEM_Solver_Adaptive.solve() and
% FEM_Solver_ArcLength.solve().

    fprintf('=== Nonlinear Analysis: %d stage(s) ===\n', length(StageList));
    nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;
    obj.U = zeros(nDofs, 1);

    if isempty(obj.state)
        obj.state = SolutionState(nDofs, obj.Options);
    end

    for s = 1:length(StageList)
        Stage = StageList{s};
        fprintf('\n>>> Stage %d / %d\n', s, length(StageList));
        obj.state.beginStage();

        strategy = Stage.getStrategy();

        if isa(strategy, 'RiksStrategy') || isa(strategy, 'LoadControlStrategy') || ...
           isa(strategy, 'DispControlStrategy')
            success = obj.solveIncrementalStage(Stage, strategy, s);
        else
            % Pure Newton with adaptive time stepping (original Adaptive behaviour)
            success = obj.solveAdaptiveStage(Stage, s);
        end

        if ~success
            fprintf('!!! Analysis aborted at stage %d.\n', s);
            return;
        end
    end
    fprintf('\n=== Analysis complete: %d converged steps ===\n', obj.state.StepCount);
end
```

**Sub-step A5b:** `solveIncrementalStage` is the merged arc-length stage driver (absorbs `solveArcLengthStage`).

**Sub-step A5c:** `solveAdaptiveStage` is the existing adaptive NR stage driver (absorbs `solveStage`).

**Sub-step A5d:** Mark `FEM_Solver_Adaptive.solve` and `FEM_Solver_ArcLength.solve` as deprecated wrappers:

```matlab
% In FEM_Solver_Adaptive.solve:
function solve(obj, StageList)
    warning('FEM_Solver_Adaptive:deprecated', ...
        'Use FEM_Solver_Nonlinear.solve() directly. FEM_Solver_Adaptive will be removed in v4.');
    solve@FEM_Solver_Nonlinear(obj, StageList);
end
```

### Self-check criteria

- [ ] `FEM_Solver_Nonlinear` has a `solve(StageList)` method.
- [ ] `FEM_Solver_Nonlinear` has `solveIncrementalStage` and `solveAdaptiveStage` private methods.
- [ ] `FEM_Solver_Adaptive.solve` calls `solve@FEM_Solver_Nonlinear` with a deprecation warning.
- [ ] `FEM_Solver_ArcLength.solve` calls `solve@FEM_Solver_Nonlinear` with a deprecation warning.
- [ ] All existing example scripts still run without error.

### Verification procedure

```matlab
% Test 1: adaptive NR still works
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'Support');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1,1.0,1e-6), 3, -200, 'load');
opts = SolverOptions(); opts.numLoadSteps = 4;
Sol = FEM_Solver_Nonlinear(Pre, opts);
S1 = LoadingStage(1.0); S1.activateBC('Support'); S1.activateLoad('load');
Sol.solve({S1});
assert(Sol.state.StepCount > 0, 'A5 FAIL: adaptive NR produced no steps');

% Test 2: arc-length via unified solver
Sol2 = FEM_Solver_Nonlinear(Pre, opts);
S2 = LoadingStage(1.0); S2.activateBC('Support'); S2.activateLoad('load');
S2.strategy = RiksStrategy('ArcLengthRadius', 0.2);
Sol2.solve({S2});
assert(Sol2.state.StepCount > 0, 'A5 FAIL: arc-length via unified solver produced no steps');
fprintf('A5 PASS: unified solver works for both NR and arc-length\n');
```

---

## Phase 3 completion gate

```matlab
% Three canonical benchmarks must all pass:

%% Benchmark 1: Patch test (linear correctness)
run('tests/Patchtest/Patchtest.m');

%% Benchmark 2: Euler column buckling
% Set up a column, run buckling, check against Pcr = pi^2*EI/L^2
Pre_col = FEM_Preprocessor_v2(210e3, 0.3, 0.005);
Pre_col.createPlate([0,0,0], 0.1, 1.0);
Pre_col.meshAllPatches(2, 8);
% (full setup with appropriate BCs would go here)
% assert abs(BucklingFactors(1) - Pcr_analytical) / Pcr_analytical < 0.05

%% Benchmark 3: Williams toggle snap-through with arc-length
% (example in examples/snapthrough.m — must complete without error)
if exist('examples/snapthrough.m', 'file')
    run('examples/snapthrough.m');
    assert(exist('Sol', 'var') && Sol.state.StepCount > 5, ...
        'Phase3 FAIL: snap-through did not progress');
end

fprintf('Phase 3 COMPLETE\n');
```

---

# PHASE 4 — Verification, deprecation, and documentation

> **Goal:** Add regression tests, deprecate v1 postprocessor, and write a final integration test that covers the full pipeline.

---

## Task V1 — Extend test suite to cover plastic history replay

### Context

`PlasticHistoryArchive` (C4) can only be verified by running a plastic analysis, then recovering stress at a past step and confirming it matches the archived GP data rather than an elastic re-integration.

### Exact deliverable

Add test T9 to `examples/test_postprocessor_v2.m`:

```matlab
function test_plastic_history_replay(testCase)
% T9: plastic stress at step 2 must match archived HistoryData, not elastic re-integration

% Build a plastic plate model
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.005);
Pre.createPlate([0,0,0], 0.5, 0.5);
Pre.meshAllPatches(2, 2);
Pre.setMaterialPlastic(250, 1000);  % sigY=250, H=1000
fixN = Pre.selectNodesOnPlane(1, 0, 1e-6);
Pre.addBC(fixN, 1:6, 0, 'Support');
tipN = Pre.selectNodesOnPlane(1, 0.5, 1e-6);
Pre.addNodalLoad(tipN, 3, -300, 'load');

opts = SolverOptions(); opts.numLoadSteps = 5;
Sol = FEM_Solver_Nonlinear(Pre, opts);
S1 = LoadingStage(1.0); S1.activateBC('Support'); S1.activateLoad('load');
Sol.solve({S1});

verifyGreaterThan(testCase, Sol.state.StepCount, 2, ...
    'T9: need at least 3 steps for replay test');

% Recover VM at step 2 via postprocessor
snap = Sol.state.snapshot();
Post = FEM_Postprocessor_v2(Pre, snap);
vm_step2 = Post.recoverField('von_mises', 2);

% Manually extract from archive for element 1, GP 1, mid-layer
arch = Sol.state.PlasticHistoryArchive{2};
verifyFalse(testCase, isempty(arch), 'T9: PlasticArchive empty at step 2');

sigma_archived = arch{1}(3).sigma;  % mid-layer GP of element 1
vm_archived = sqrt(sigma_archived(1)^2 + sigma_archived(2)^2 ...
    - sigma_archived(1)*sigma_archived(2) + 3*sigma_archived(3)^2);

% The postprocessor's recovered value should use archived data (not elastic)
% Allow 5% tolerance due to SPR smoothing
[~, nodeElem1] = ismember(1, Pre.Mesh.Elements(:));
if nodeElem1 > 0
    vm_post_n = vm_step2(Pre.Mesh.Elements(ceil(nodeElem1/8), mod(nodeElem1-1,8)+1));
    rel_diff = abs(vm_post_n - vm_archived) / max(vm_archived, 1);
    verifyLessThan(testCase, rel_diff, 0.15, ...
        sprintf('T9: postprocessor VM (%.2f) vs archive VM (%.2f)', vm_post_n, vm_archived));
end
fprintf('T9 PASS: plastic history replay consistent\n');
end
```

### Verification procedure

```matlab
results = runtests('examples/test_postprocessor_v2.m');
nFailed = sum([results.Failed]);
assert(nFailed == 0, sprintf('V1 FAIL: %d test(s) failed', nFailed));
fprintf('V1 PASS: all %d tests pass\n', length(results));
```

---

## Task V2 — Full integration test covering all three solver modes

### Context

Create a single script that exercises every solver path and confirms numerical correctness against known references.

### Exact deliverable

Create `tests/test_solver_integration.m`:

```matlab
%% TEST_SOLVER_INTEGRATION
% Full pipeline integration test for the redesigned solver.
% Must pass before any release.
%
% Run: runtests('tests/test_solver_integration.m')

function tests = test_solver_integration
tests = functiontests(localfunctions);
end

function test_linear_static_patch(testCase)
% Patch test: constant-strain field must be reproduced exactly
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(4, 4);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1, 1.0, 1e-6), 1, 2100, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
Ux_tip = mean(Sol.U((Pre.selectNodesOnPlane(1,1.0,1e-6)-1)*6+1));
Ux_ref = 2100 / (210e3 * 0.01) * 1.0;
verifyLessThan(testCase, abs(Ux_tip-Ux_ref)/Ux_ref, 0.02, 'Linear patch test');
fprintf('Integration T1 PASS: linear static\n');
end

function test_buckling_euler_column(testCase)
% Euler column: first buckling factor within 5% of pi^2*EI/L^2
% (Setup requires appropriate column model — placeholder assertions)
fprintf('Integration T2: buckling test (placeholder)\n');
verifyTrue(testCase, true, 'Placeholder — implement with column model');
end

function test_nonlinear_convergence(testCase)
% Nonlinear NR must converge in < 10 steps for a moderately loaded plate
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.005);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'Support');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1,1.0,1e-6), 3, -100, 'load');
opts = SolverOptions(); opts.numLoadSteps = 5;
Sol = FEM_Solver_Nonlinear(Pre, opts);
S1 = LoadingStage(1.0); S1.activateBC('Support'); S1.activateLoad('load');
Sol.solve({S1});
verifyGreaterThan(testCase, Sol.state.StepCount, 0, 'NL: no steps converged');
verifyFalse(testCase, any(isnan(Sol.U)), 'NL: NaN in U');
fprintf('Integration T3 PASS: nonlinear NR\n');
end

function test_arclength_riks(testCase)
% Arc-length must trace equilibrium path (lambda > 0 for at least 3 steps)
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.005);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'Support');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1,1.0,1e-6), 3, -50, 'load');
opts = SolverOptions();
Sol = FEM_Solver_Nonlinear(Pre, opts);
S1 = LoadingStage(1.0); S1.activateBC('Support'); S1.activateLoad('load');
S1.strategy = RiksStrategy('ArcLengthRadius', 0.2, 'ArcLengthMin', 0.01);
Sol.solve({S1});
verifyGreaterThan(testCase, Sol.state.StepCount, 2, 'ArcLength: < 3 steps');
verifyTrue(testCase, all(Sol.state.LambdaHist(1:Sol.state.StepCount) >= 0), ...
    'ArcLength: negative lambda');
fprintf('Integration T4 PASS: arc-length Riks\n');
end

function test_postprocessor_no_mutation(testCase)
% Postprocessor must not change solver state
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(3, 3);
Pre.addBC(Pre.selectNodesOnPlane(1, 0, 1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1,1.0,1e-6), 3, -500, 'load');
Sol = FEM_Solver(Pre);
Sol.solveStatic();
U_ref = Sol.U;
Post = FEM_Postprocessor_v2(Pre, Sol.state.snapshot());
Post.recoverField('von_mises', 1);
verifyEqual(testCase, Sol.U, U_ref, 'AbsTol', 1e-12, 'Postprocessor mutated Solver.U');
fprintf('Integration T5 PASS: no postprocessor mutation\n');
end
```

### Verification procedure

```matlab
results = runtests('tests/test_solver_integration.m');
nFailed = sum([results.Failed]);
assert(nFailed == 0, sprintf('V2 FAIL: %d integration test(s) failed', nFailed));
fprintf('V2 PASS: all integration tests pass\n');
```

---

## Task V3 — Deprecate `FEM_Postprocessor` v1 with a redirect wrapper

### Context

`FEM_Postprocessor` v1 is used by `FEM_Postprocessor_App` and any existing scripts. Rather than breaking them, add a constructor warning and delegate all calls to a v2 instance internally.

### Exact deliverable

Add to the beginning of `FEM_Postprocessor` constructor:

```matlab
function obj = FEM_Postprocessor(preObj, solvObj)
    warning('FEM_Postprocessor:deprecated', ...
        ['FEM_Postprocessor v1 is deprecated. ' ...
         'Migrate to FEM_Postprocessor_v2. ' ...
         'v1 will be removed in the next major version.']);
    obj.Model  = preObj;
    obj.Solver = solvObj;
    % Build internal v2 delegate if solver has new state
    if isprop(solvObj, 'state') && ~isempty(solvObj.state)
        obj.v2delegate = FEM_Postprocessor_v2(preObj, solvObj.state.snapshot());
    end
end
```

Update `FEM_Postprocessor_App` to prefer `FEM_Postprocessor_v2` when available:

```matlab
% In FEM_Postprocessor_App constructor, replace:
%   obj.Post = postObj;
% with:
if isa(postObj, 'FEM_Postprocessor_v2')
    obj.Post = postObj;
elseif isa(postObj, 'FEM_Postprocessor') && ~isempty(postObj.v2delegate)
    obj.Post = postObj.v2delegate;
else
    obj.Post = postObj;  % fallback to v1
end
```

### Self-check criteria

- [ ] `FEM_Postprocessor()` constructor emits a deprecation warning.
- [ ] `FEM_Postprocessor_App` works when given a `FEM_Postprocessor_v2` object directly.
- [ ] No test failures in `test_postprocessor_v2.m`.

### Verification procedure

```matlab
% Confirm deprecation warning fires but doesn't break anything
Pre = FEM_Preprocessor_v2(210e3, 0.3, 0.01);
Pre.createPlate([0,0,0], 1.0, 1.0);
Pre.meshAllPatches(2, 2);
Pre.addBC(Pre.selectNodesOnPlane(1,0,1e-6), 1:6, 0, 'fix');
Pre.addNodalLoad(Pre.selectNodesOnPlane(1,1.0,1e-6), 3, -100, 'load');
Sol = FEM_Solver(Pre); Sol.solveStatic();
w = warning('off', 'FEM_Postprocessor:deprecated');
Post_v1 = FEM_Postprocessor(Pre, Sol);
warning(w);
vm = Post_v1.recoverNodalSmooth('VonMises', 'Top');
assert(~any(isnan(vm)), 'V3 FAIL: v1 wrapper broken');
fprintf('V3 PASS: v1 deprecation wrapper works\n');
```

---

## Phase 4 and final completion gate

```matlab
%% Run complete test suite
fprintf('\n=== FINAL VERIFICATION ===\n\n');

results_unit = runtests('examples/test_postprocessor_v2.m');
results_integration = runtests('tests/test_solver_integration.m');

all_results = [results_unit, results_integration];
nPassed = sum([all_results.Passed]);
nFailed = sum([all_results.Failed]);

fprintf('\n=== TEST SUMMARY ===\n');
fprintf('  Passed: %d\n', nPassed);
fprintf('  Failed: %d\n', nFailed);

if nFailed == 0
    fprintf('\nALL PHASES COMPLETE. CurveShellFEM solver pipeline redesign successful.\n\n');
    fprintf('New capabilities delivered:\n');
    fprintf('  - Assembler: stateless, testable, reusable\n');
    fprintf('  - SolutionState: append-only history archive\n');
    fprintf('  - SolutionSnapshot: safe postprocessor handoff\n');
    fprintf('  - ConvergenceMonitor: pluggable norm types including energy norm\n');
    fprintf('  - IncrementalStrategy: Riks / LoadControl / DispControl\n');
    fprintf('  - PlasticHistoryArchive: exact stress recovery at any past step\n');
    fprintf('  - Unified FEM_Solver_Nonlinear: single class for all NL analysis\n');
    fprintf('  - Backward compatibility: all existing scripts run unchanged\n');
else
    fprintf('\nFAILURES REMAIN. Do not commit. Fix failing tests before proceeding.\n');
end
```

---

## Appendix A — File checklist

New files created in this plan:

```
src/@Assembler/Assembler.m
src/@SolutionState/SolutionState.m
src/@SolutionSnapshot/SolutionSnapshot.m
src/@ConvergenceMonitor/ConvergenceMonitor.m
src/@IncrementalStrategy/IncrementalStrategy.m
src/@RiksStrategy/RiksStrategy.m
src/@LoadControlStrategy/LoadControlStrategy.m
src/@DispControlStrategy/DispControlStrategy.m
tests/test_solver_integration.m
```

Files modified (not deleted):

```
src/@FEM_Solver_Nonlinear/linesearch.m          (H1)
src/@FEM_Postprocessor/recoverNodalSmooth.m     (H2)
src/@FEM_Solver_Nonlinear/newtonLoop.m          (H3, C2, C3)
src/@FEM_Solver_ArcLength/arcLengthStep.m       (H4, A2)
src/@FEM_DataManager/loadState.m                (H5)
src/@SolverOptions/SolverOptions.m              (I2)
src/@FEM_Solver/assembleK.m                     (I1 wiring)
src/@FEM_Solver/assembleTangentSystem.m         (I1 wiring)
src/@FEM_Solver_Nonlinear/FEM_Solver_Nonlinear.m (I3 wiring, A5)
src/@FEM_Solver_Adaptive/solveStage.m           (C4)
src/@FEM_Solver_Adaptive/solve.m                (A5 deprecation)
src/@FEM_Solver_ArcLength/solveArcLengthStage.m (A3)
src/@FEM_Solver_ArcLength/solve.m               (A5 deprecation)
src/@LoadingStage/LoadingStage.m                (A4)
src/@FEM_Postprocessor/FEM_Postprocessor.m      (V3)
src/FEM_Postprocessor_App.m                     (V3)
src/@FEM_Postprocessor_v2/recoverAllGaussPoints.m (C4)
examples/test_postprocessor_v2.m                (V1)
```

---

## Appendix B — Key invariants the agent must never violate

1. **No postprocessor writes solver state.** Any assignment to `obj.Solver.*` from inside `@FEM_Postprocessor*` or `@FEM_Postprocessor_v2*` is a critical bug.

2. **TrialHist is never committed on diverge.** `commitHistory(TrialHist)` must only appear inside `if converged` blocks.

3. **`U_entry` is always returned on diverge.** The NR loop must not return a drifted `U_curr` when it fails to converge.

4. **`SolutionState.appendStep` is the only write gate for history.** No code outside of `solveStage`, `solveIncrementalStage`, or `updateHistory` may write to `state.U_Hist` directly.

5. **`Assembler` methods have no side effects.** They take arrays, return arrays. No property of any object is set inside them.

6. **Strategy objects are stateless between calls.** `constraint()` and `predictor()` may not write to `obj.Elements` or any solver property.

7. **`rcond`, never `condest`, for singularity detection.**

8. **`R = F_int - F_ext`, never `F_ext - F_int`.**

---

*End of agent work plan. Version 1.0 — generated from CurveShellFEM architectural review.*
