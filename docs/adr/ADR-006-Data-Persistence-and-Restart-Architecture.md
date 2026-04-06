# ADR-006: Data Persistence and Restart Architecture (Stage-Aware Snapshots)

**Phase**: 29
**Date**: 2026-04-06
**Author**: Lead Architect
**Status**: Proposed

---

## Context

`FEM_DataManager` currently provides full-state save/load in MAT format and CSV export, but it is not yet integrated as a stage-aware persistence service for nonlinear workflows. The current implementation saves a single `<ProjectName>_FullState.mat` file, making coarse restart possible but limiting:

- partial restart from a specific converged step,
- robust recovery from interrupted long arc-length runs,
- scalable storage of large history arrays,
- explicit metadata for stage/step provenance and compatibility checks.

Current code evidence:

1. Class shell and basic API (`saveState`, `loadState`) exist.
2. MAT serialization writes mesh/material/BC/load/results/history to one file.
3. Load reconstructs `FEM_Preprocessor`, `FEM_Solver`/plastic solver and selected histories.
4. Schema validator exists but is not wired into persistence lifecycle.

**Alternatives considered**:
1. Single monolithic MAT file per run — simplest but poor restart granularity and weak crash resilience.
2. Pure CSV/JSON persistence — human-readable but unsuitable for dense numeric histories and GP data.
3. Hybrid metadata + binary arrays (chosen) — explicit metadata with step/stage appendable binary datasets.

---

## Decision

The project uses a **MAT-first, stage-aware persistence architecture** with:

1. **Canonical metadata in JSON** for project/stage/step indices, schema version, compatibility, and restart points.
2. **Numeric payloads in MAT files** (`preprocessor.mat`, `steps.mat`, `gp_history.mat`, `checkpoint.mat`) for MATLAB-native IO and drop-in adoption.
3. **Incremental step persistence via `save(..., '-append')`** in `steps.mat` to grow step-level variables without rewriting the full project state.

### On-disk model

```
<ProjectRoot>/
  project_meta.json
  preprocessor.mat
  element_cache.mat
  stages/
    stage_001/
      stage_meta.json
      steps.mat
      gp_history.mat          (optional if constitutive history is enabled)
      checkpoint.mat          (last converged step snapshot)
    stage_002/
      ...
```

### Logical data entities

- **ProjectMeta**: format version, solver family, mesh hash, material signature, stage count, created/updated timestamps.
- **PreprocessorState**: `Mesh`, `BCs`, `Loads`, `Material`, normals, optional named tags.
- **ElementCacheState**: `Elements`-rebuild key data (`SctrMap`, element type map, integration settings).
- **StageMeta**: stage index, active BC/load tags, constraint type, arc-length parameters, step counters.
- **StepRecord** (append-only in `steps.mat`): converged `U`, `lambda`, `time`, residual/iteration metrics, status.
- **HistoryRecord** (optional): element/GP internal variables for plasticity and path-dependent models.
- **CheckpointState**: minimal restart image for solver object state + pointer to last committed step.

### API contract (enhanced `FEM_DataManager`)

- `initProject(pre, sol, opts)`
  - Creates project folder, writes baseline metadata, and stores immutable preprocess/cache artifacts.
- `saveSnapshot(pre, sol, opts)`
  - Writes `project_meta.json` and stable preprocessor/cache artifacts.
- `appendStep(stageId, stepPayload)`
  - Appends converged step vectors/scalars to `steps.mat` via `save(..., '-append')`; updates `stage_meta.json` atomically.
- `onStepConverged(stageId, solverState)`
  - Event callback wrapper that extracts canonical step payload and calls `appendStep`.
- `saveCheckpoint(stageId, stepId, pre, sol, historyPayload)`
  - Writes rolling `checkpoint.mat` for rapid restart.
- `loadSnapshot(mode, key)`
  - `mode = "project" | "stage" | "step"`; reconstructs solver state accordingly.
- `listSteps(stageId)` / `listRestartPoints()`
  - Enumerates valid restart anchors by reading metadata only.
- `restartFromStage(stageId)`
  - Loads preprocessor + last stage checkpoint.
- `restartFromStep(stageId, stepId)`
  - Loads preprocessor + step column + constitutive history up to selected converged step.
- `attachToSolver(sol, stageId)`
  - Registers data manager listener to `StepConverged` for incremental persistence in nonlinear workflows.

### Data flow by lifecycle stage

1. **Preprocess complete**
   - Run schema validation once.
   - Persist immutable preprocessor and cache artifacts.
2. **Solver running (per converged step)**
   - On convergence event, call `appendStep`.
   - Every `N` steps (or stage end), call `saveCheckpoint`.
3. **Stage transition**
   - Seal `stage_meta` (`status = complete`, `last_converged_step`).
   - Create next stage directory and initialize metadata.
4. **Postprocess**
   - Read-only access to steps/history datasets; no solver object mutation.
5. **Restart**
   - Query restart points from metadata.
   - Hydrate solver from chosen stage/step payload and continue with new StageList tail.

### Consistency and safety rules

- Metadata writes are atomic (`*.tmp` + rename).
- Step append is monotonic and never overwritten.
- `checkpoint.mat` is replaceable but always references immutable step ids.
- Restart requires compatibility checks: mesh hash, DOF count, material model id, solver family.
- `saveState/loadState` remain as compatibility wrappers during migration, internally delegating to new APIs when possible.

---

## Consequences

**Positive**:
- Enables fine-grained restart from stage or exact converged step.
- Scales better for large histories via appendable MAT step archives.
- Improves recoverability after interruption with frequent checkpoints.
- Separates immutable model definition from mutable solve history.

**Negative / trade-offs**:
- Introduces more files/directories and metadata management complexity.
- Requires migration logic for legacy single-file MAT saves.
- Necessitates stricter schema/version governance.

**Constraints introduced**:
- New persistence code must be append-safe and versioned.
- Stage/step IDs become canonical identifiers in solver and postprocessor APIs.
- Any future solver with path-dependent state must implement HistoryRecord serialization.

---

## Compliance

How is this decision verified to be enforced in `src/`?

| Check | Location | Verification |
|:------|:---------|:-------------|
| Existing DataManager baseline API available | `src/@FEM_DataManager/FEM_DataManager.m` | Current implementation inspection |
| Current MAT save/load path available for migration | `src/@FEM_DataManager/saveToMAT.m`, `src/@FEM_DataManager/loadState.m` | Current implementation inspection |
| Stage/step nonlinear histories exist in solver classes | `src/@FEM_Solver_Nonlinear/`, `src/@FEM_Solver_ArcLength/` | Current implementation inspection |

**Verification report cross-reference**: not yet verified

---

## Implementation Plan (Phase 1–4)

1. **Phase 1 — Foundation (no solver changes, ~1 week)**
   - Implement `initProject`, `saveSnapshot` (replaces `saveToMAT`), `loadSnapshot` (replaces `loadState`), and `listRestartPoints`.
   - Keep this as a drop-in replacement for existing scripts and object flows.
   - Preserve compatibility wrappers `saveState/loadState` to call new core methods.

2. **Phase 2 — Incremental writes (~2 weeks)**
   - Implement `appendStep` and `onStepConverged`.
   - Wire event listener via `DM.attachToSolver(Sol, stageId)` in example scripts.
   - Persist two growing artifacts per converged step in `steps.mat`:
     - `U_step_k`
     - `step_meta_k` (small struct with lambda/time/iters/status)
   - Use MATLAB `save(..., '-append')` to avoid full-file rewrites.

3. **Phase 3 — Restart (1–2 weeks + focused tests)**
   - Implement `restartFromStage` and `restartFromStep`.
   - Rebuild `Sol.Elements` and scatter/cache state from saved preprocessor + constitutive history.
   - Enforce tangent-equivalence goal: first Newton iteration after restart must match uninterrupted run.

4. **Phase 4 — Postprocessor integration**
   - Extend `FEM_Postprocessor_v2.recoverAllGaussPoints` to optionally read `gp_history.mat` instead of live `Elements{e}.HistoryData`.
   - Enable full-history animation/recovery without retaining complete history in RAM.

### Minimal database model (optional, future)

If project-level search/query across many runs becomes necessary, add optional SQLite index:

- `projects(project_id, name, version, created_at, mesh_hash, solver_family)`
- `stages(stage_id, project_id, stage_no, constraint_type, status, last_step)`
- `steps(step_id, stage_id, step_no, time, lambda, converged, iter_count, checkpoint_path)`
- `artifacts(artifact_id, project_id, stage_id, kind, path, checksum, bytes)`

The SQL index is optional and never replaces MAT-based numeric storage.

---

## Supersedes / superseded by

N/A

---

*Lead Architect — 2026-04-06*
*Accepted by Lead Architect: PENDING*
