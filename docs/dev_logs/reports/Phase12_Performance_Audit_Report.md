# Lead Architect Report: Phase 12 Performance Audit

**Date**: 2026-03-27  
**Phase**: 12 (Performance Optimization & Parallelization)  
**Status**: **AUDIT COMPLETE** (Pre-implementation phase)

---

## 1. Executive Summary
As requested, a formal performance audit was conducted *prior* to any code modification. The MATLAB Profiler was run on the `benchmark_gmnia_cylindrical_panel.m` script (Arc-Length solver, J2 Plasticity). Results highlight that **element-level tangent stiffness calculation and global matrix assembly** account for the vast majority of CPU time. 

---

## 2. Profiler Data (Top 10 Bottlenecks)
Based on a short 16-element, 2-increment GMNIA baseline run:

| Function | Time (s) | Calls | Cause / Context |
|:---------|:---------|:------|:----------------|
| `FEM_Solver.assembleTangentSystem` | 0.399 | 8 | Main sequential loop over all elements. |
| `Curve8Element.computeGlobalMatrix6DOF` | 0.362 | 128 | Element 5-to-6 DOF expansion & drilling stabilization. |
| `ArcLength>assembleForArcLength` | 0.342 | 6 | Duplicate sequential loop for Arc-Length tangent. |
| `Curve8Element.computeTangentStiffnessAndForce` | 0.285 | 128 | Heavy integration: 3x3x5 layers, material nonlinear laws. |
| `FEM_Preprocessor_v2.addBC` | 0.196 | 3 | Table instantiation overhead. |
| `condest` (Condition check) | 0.113 | 4 | Matrix conditioning check in linear solver. |
| `Curve8Element.calculateKinematics` | 0.084 | 1536 | Shape function Jacobians (called per Gauss point). |
| `Curve8Element.formBmb` | 0.078 | 512 | B-matrix formation. |

---

## 3. Diagnostic Breakdown
1. **The Assembly Loop**: The loop over `nElements` inside `assembleTangentSystem` and `assembleForArcLength` evaluates sequentially. Because stiffness matrices for each element only depend on their own state (coordinates, history), this is an **embarrassingly parallel** problem.
2. **Arc-Length Duplication**: The Arc-Length solver has its own `assembleForArcLength` method that duplicates the loop in `assembleTangentSystem`. Unifying these or applying the same parallelization will double the impact.
3. **Element Integration (Vectorization)**: `computeTangentStiffnessAndForce` has deeply nested `for` loops (Gauss points and layer points). While `calculateKinematics` is somewhat vectorized, the assembly over thickness layers evaluates the material model point-by-point.

---

## 4. Proposed Mitigation Strategy

### Step 1: `parfor` Global Assembly (High Impact)
Convert the main element loops in `FEM_Solver.assembleTangentSystem` and `FEM_Solver_ArcLength>assembleForArcLength` to `parfor`.
* **Challenge**: `parfor` in MATLAB forbids appending to global `sparse` matrices (`K_global(idx, idx) = K_global + Ke`). 
* **Solution**: Build vectors of indices (`I_all`, `J_all`, `V_all` and `F_all`) inside the `parfor` loop, and construct the sparse matrix (`sparse(I_all, J_all, V_all)`) *after* the loop closes.

### Step 2: `addBC` Minor Optimization (Easy Win)
While `addNodalLoad` was completely bulk-optimized in Phase 11, `addBC` still creates its own `table` and expands via `repmat`. It took 0.196s (15% of runtime). We will refine it to avoid MATLAB's `table` allocation overhead by pre-structuring the arrays.

### Step 3: Material State History (Data Race Prevention)
In a `parfor` loop, updating `obj.Elements{e}.HistoryData` is a property mutation which violates `parfor` transparency rules. We will extract `HistoryData` into a structured array, pass it to the `parfor` loop, generate `NewHistoryData`, and write it back post-loop.

---

## 5. Next Steps
Pending your approval of this audit, the **Core Implementer** will proceed with substituting standard `for` loops with `parfor` structures and index-vector sparse assembly.
