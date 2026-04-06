# Phase 13+: FEM_Postprocessor v2 — Architecture & Refactoring Specification

**Date**: 2026-04-02  
**Author**: Lead Architect (Claude Sonnet 4.6)  
**Status**: IMPLEMENTATION READY  
**Scope**: `src/@FEM_Postprocessor`, `src/@Curve8Element` (2 new methods), `src/@FEM_Solver` (1 fix)

---

## 1. Root Cause Analysis (5 confirmed bugs)

### Bug 1 — DOF stripping never happens at post-processing time

**Location**: `computeStresses.m` (called by all postprocessor paths)  
**Evidence**: `computeGlobalMatrix6DOF` performs a 48→40 DOF strip
(`u_loc(6:6:end) = []`) and a `per_5_blkdiag()` permutation before
passing the displacement vector to the element integration kernel.
This transform is absent in every post-processing call path.
A raw 48-DOF slice from `U_Hist` is passed to `computeStresses`,
so the drilling DOF (index 6, 12, 18…) corrupts every strain
computation and the `[u,v,w,Rv1,Rv2]→[u,v,w,α,β]` permutation is
never applied.

**Impact**: All stress outputs are wrong for any non-trivial loading.

---

### Bug 2 — Green-Lagrange A_geom correction discarded at post-processing time

**Location**: `computeStresses.m` line `eps_m = Bm * u_elem`  
**Evidence**: `computeTangentStiffnessAndForce` computes membrane strain as:
```
eps_m = Bm0 * u_mix + 0.5 * A_geom * theta_k
```
where `A_geom` captures the nonlinear coupling between transverse
displacement gradients and in-plane strains (von Kármán approximation).
`computeStresses` uses only `Bm * u_elem` — the linear part — so
stresses are systematically underestimated after any GNI or GMNIA step.

**Impact**: Post-processing stress fields are inconsistent with the
assembled residual for all geometric nonlinear analyses.

---

### Bug 3 — Plastic stress recovery uses elastic constitutive matrix

**Location**: `computeStresses.m` line `sigma_plane = D_mb(1:3,1:3) * eps_total`  
**Evidence**: The correct stress at each Gauss point after a plastic
increment is stored in `Elements{e}.HistoryData(pt).sigma` immediately
after `commitHistory` is called. `computeStresses` never reads this
field; instead it multiplies the elastic `D_el` by the total strain.
In the plastic regime `sigma ≠ D_el * eps_total` by definition
(the yield surface constraint has been enforced).

**Impact**: All stress fields are physically wrong after any plastic
loading. The error grows monotonically with plastic strain magnitude.

---

### Bug 4 — `computeGlobalForceONLY` does not exist

**Location**: `assembleinternalforceONLY.m` line `fe = elObj.computeGlobalForceONLY(u_el)`  
**Evidence**: `Curve8Element.m` lists no such method. The line-search
path in `FEM_Solver_Nonlinear.linesearch` calls
`assembleinternalforceONLY`, which calls this nonexistent method,
causing a crash at runtime when line search is enabled.

**Impact**: Line-search (UseLineSearch = true) always crashes.

---

### Bug 5 — SPR/ZZ error estimator is a phantom feature

**Location**: `FEM_Solver_Adaptive.solve` line
`[err_el, total_err] = Post.estimateErrorNorms()`  
**Evidence**: The adaptive refinement loop inside `solve.m` instantiates
`FEM_Postprocessor` and calls `estimateErrorNorms`. This method does not
exist in any provided source file, so the adaptive solve crashes at the
first refinement check. The session logs (Phase 7) claim SPR was
implemented, but no corresponding code was delivered.

**Impact**: `FEM_Solver_Adaptive.solve` crashes on every call after the
first converged step. The refinement loop has never been functional.

---

## 2. New Architecture

### 2.1 Design principle

> Post-processing must **replay the same computational pipeline as the
> solver**, not invent a parallel one. Stress is never recomputed from
> first principles at post-processing time; it is recovered from the
> already-correct committed state in `HistoryData`.

### 2.2 Two-stage pipeline

```
Stage 1: Gauss-point recovery (element-local, lossless)
  For each element e:
    u_el = U_Hist(SctrMap(e,:), stepIdx)          ← 48-DOF
    gpData[e] = Elements{e}.recoverGaussPointData(u_el)

    Inside recoverGaussPointData:
      u_loc = T_cached * u_el                     ← rotate
      u_loc(6:6:end) = []                         ← strip drilling (FIX BUG 1)
      u_mix = per_5_blkdiag() * u_loc             ← permute

      IF MaterialModel set AND HistoryData valid:
        → READ sigma, eps_p, p from HistoryData   ← exact (FIX BUG 3)
      ELSE:
        → integrate with D_el and A_geom term     ← correct (FIX BUG 2)

      Returns [20×1] gpData struct:
        .sigma, .eps_total, .eps_p, .p
        .von_mises, .sigma_principal, .yielded

Stage 2: Nodal projection (Zienkiewicz-Zhu SPR)
  For each node n:
    patch = {all elements sharing node n}
    GP positions and values from patch → [A | b] = [[1,x,y] | v]
    a = A \ b  (linear polynomial fit, LS)
    nodalVal(n) = [1, xn, yn] * a
```

### 2.3 Class diagram

```
FEM_Postprocessor (handle)
│
├── Properties
│     Model      : FEM_Preprocessor_v2 handle
│     Solver     : FEM_Solver (any subclass) handle
│     CachedStep : int   (GP cache key)
│     CachedGP   : cell  (GP cache value)
│
├── Public API
│     recoverField(fieldName, stepIdx)          → [nNodes×1]
│     estimateErrorNorms(stepIdx)               → [errEl, totalNorm]
│     plotField(fieldName, stepIdx, opts)
│     plotPlasticYield(stepIdx)
│     animateHistory(nodeID, dofIdx)
│     plotReactionDispCurve(rHist,nID,dof,s)
│
└── Private pipeline
      recoverAllGaussPoints(stepIdx)            → {nElems×1} cell
      recoverNodalSPR(gpCell, fieldName)        → [nNodes×1]
      recoverNodalAverage(gpCell, fieldName)    → [nNodes×1]  (fallback)
      extractGPScalar(gpCell, fieldName)        → {nElems×1} cell
      getDisplacementAtStep(stepIdx)            → [nDOFs×1]

Curve8Element (existing class, 2 new methods)
  + recoverGaussPointData(u_global_48)         → [20×1] gpData struct
  + computeGlobalForceONLY(u_el)              → [48×1] fe_global
```

---

## 3. File manifest

### New files (deliver all)

| File | Purpose |
|:-----|:--------|
| `src/@Curve8Element/recoverGaussPointData.m` | Fix Bugs 1+2+3: authoritative GP stress recovery |
| `src/@Curve8Element/computeGlobalForceONLY.m` | Fix Bug 4: missing method for line-search path |
| `src/@FEM_Postprocessor/FEM_Postprocessor.m` | Class definition with full method signatures |
| `src/@FEM_Postprocessor/recoverAllGaussPoints.m` | Stage 1 pipeline (element loop + cache) |
| `src/@FEM_Postprocessor/recoverNodalSPR.m` | Stage 2 pipeline (ZZ superconvergent projection) |
| `src/@FEM_Postprocessor/recoverNodalAverage.m` | Stage 2 fallback (inverse-distance weighted avg) |
| `src/@FEM_Postprocessor/recoverField.m` | Public dispatcher: kinematic vs stress routing |
| `src/@FEM_Postprocessor/extractGPScalar.m` | Internal: fieldName → gpData field mapping |
| `src/@FEM_Postprocessor/estimateErrorNorms.m` | Fix Bug 5: ZZ error estimator |
| `src/@FEM_Postprocessor/plotField.m` | 3D contour renderer with deformed shape overlay |
| `src/@FEM_Postprocessor/plotPlasticYield.m` | Through-thickness yield front visualisation |
| `src/@FEM_Postprocessor/animateHistory.m` | Slider-driven history animation |
| `src/@FEM_Postprocessor/animateHistory.m` | `plotReactionDispCurve` is in this same file |
| `src/@FEM_Postprocessor/getDisplacementAtStep.m` | Private: safe U_Hist accessor |
| `tests/test_postprocessor_v2.m` | 7-test unit suite (one test per bug + API + SPR) |

### Files to deprecate (do not delete yet)

| File | Reason |
|:-----|:-------|
| `src/@Curve8Element/computeStresses.m` | Replaced by `recoverGaussPointData`. Add `@deprecated` comment. |

### Existing files requiring one-line modification

| File | Change |
|:-----|:-------|
| `src/@FEM_Solver_Adaptive/solve.m` | Remove the `FEM_Postprocessor` instantiation and `estimateErrorNorms` call from inside the stepping loop. SPR is now an explicit post-solve call, not embedded in the solver. |

---

## 4. Integration notes for `FEM_Solver_Adaptive.solve`

Replace the current adaptive refinement block (lines ~20–40 of `solve.m`):

```matlab
% REMOVE THIS BLOCK:
Post = FEM_Postprocessor(obj.Model, obj);
[err_el, total_err] = Post.estimateErrorNorms();
if total_err <= target_error
    ...
```

With a simple unconditional stage solve:

```matlab
% REPLACE WITH:
success = obj.solveStage(currentStage, s);
if ~success, break; end
% Error estimation is now the caller's responsibility:
%   Post = FEM_Postprocessor(Pre, Sol);
%   [errEl, norm] = Post.estimateErrorNorms();
```

This decouples the solver from the postprocessor and removes the
phantom SPR crash from the stepping loop.

---

## 5. Supported field names (public API)

| fieldName | Description | Source |
|:----------|:------------|:-------|
| `displacement_x/y/z` | Nodal translation | `U_Hist` direct read |
| `displacement_mag` | Magnitude of translation vector | `U_Hist` derived |
| `von_mises` | Von Mises stress | GP → SPR |
| `sigma_x / sigma_y / tau_xy` | Plane-stress components | GP → SPR |
| `sigma_1 / sigma_2` | In-plane principal stresses | GP → SPR |
| `p` | Equivalent plastic strain | GP → SPR (reads `HistoryData.p`) |
| `eps_p_x / eps_p_y` | Plastic strain components | GP → SPR |
| `yield_depth` | Through-thickness yield fraction [0,1] | GP → element constant |
| `strain_x / strain_y / gamma_xy` | Total strain components | GP → SPR |

---

## 6. Acceptance criteria (Validation Scientist checklist)

- [ ] **T1**: `recoverGaussPointData` produces identical sigma when drilling
      DOFs are set to 1e3 (vs zero). Tolerance: `‖Δσ‖ < 1e-6`.
- [ ] **T2**: After a GNI step with transverse displacement, recovered sigma
      is nonzero at at least one GP (A_geom correction active).
- [ ] **T3**: After a plastic step, `gpData.sigma` matches
      `Elements{e}.HistoryData(pt).sigma` to machine precision.
- [ ] **T4**: `computeGlobalForceONLY(u)` returns the same vector as the
      second output of `computeGlobalMatrix6DOF(u)`.
- [ ] **T5**: `estimateErrorNorms` completes without error on a 2×2
      elastic plate mesh. `errEl ∈ [0, 1.5]`, `totalNorm ≥ 0`.
- [ ] **T6**: All kinematic `recoverField` variants return `[nNodes×1]`
      vectors with no NaN.
- [ ] **T7**: `recoverNodalSPR` and `recoverNodalAverage` both return
      `[nNodes×1]` vectors with no NaN on the same test mesh.
- [ ] **Regression**: `benchmark_scordelis_lo` still achieves < 0.5% error.
- [ ] **Regression**: `benchmark_plastic_snapthrough` still converges.

---

*Report filed by Lead Architect — 2026-04-02*
