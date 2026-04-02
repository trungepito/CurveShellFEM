# Phase 27 | Task Brief: Arc-Length & Advanced Benchmarks (FEM Engineer)
**Date**: 2026-03-31  
**Phase**: 27 (Comprehensive Benchmark Suite)  
**Role**: Arc-Length Specialist (FEM Engineer)  
**Gate**: 0 → 0.5 (Awaiting Brief-Bind)

---

## 1. Objective

"Implement arc-length algorithm variants and complex kinematics benchmarks. Your responsibility is to: (1) Develop benchmark comparing Riks vs. spherical-damping constraints, (2) Create multi-limit-point problem for complex path following, (3) Implement parameter sensitivity study (radius effects on convergence), (4) Validate automatic stiffness recovery through bifurcations, (5) Document arc-length formulations and constraint comparisons."

---

## 2. Your Deliverables

### Benchmark 1: Arc-Length Constraint Comparison (Riks vs. Spherical)
**Geometry**: Classic snapthrough arch (same as Phase 26)  
**Material**: Standard steel  
**Method**: Execute identical problem with TWO constraint methods  

**Method 1: Riks Hyperplane Constraint** (current implementation, ADR-003)
$$\bar{\Delta u}^T (\bar{u}_{n-1} - \bar{u}_{n-2}) = 0$$
where modified residual: $\bar{\Delta u} = [\Delta u \; \lambda \Delta F]^T$

**Method 2: Spherical-Damping Constraint** (alternative)
$$\|\bar{\Delta u}\| = \Delta s$$
with adaptive radius $\Delta s$ based on convergence history

**Expected Outcome**:
- Both methods solve identical geometry
- Riks (current): 50 steps converged (Phase 26 verified)
- Spherical: should converge, but may differ in step distribution
- Compare convergence efficiency, iteration counts, step sizes
- Both should reach same final λ ≈ 11.35

**Reference Solution**:
- Use Riks result (Phase 26) as baseline for comparison
- Both methods should converge to same equilibrium path

**File**: `benchmark_arclength_constraint_comparison.m`

**Acceptance Criteria**:
- Riks: 50 steps converged (baseline)
- Spherical: converges to ±5% of Riks result
- Final load factor λ_final: within 1% of Riks
- Both traverse complete snap-through path

---

### Benchmark 2: Complex Equilibrium Path (Multiple Limit Points)
**Geometry**: Cylindrical panel with initial imperfection (controlled shape)  
**Material**: Steel  
**Loading**: Multi-axial load path (not simple proportional)  
**Method**: Arc-length with automatic constraint type selection  

**Expected Outcome**:
- Equilibrium path includes multiple limit points (turning points)
- Solver navigates through bifurcations without branch switching
- Complex load-displacement surface
- Arc-length tracks primary path automatically

**Reference Solution**:
- Compare with literature (Rammerstorfer et al., cylindrical panel)
- Expected critical loads at specific geometries
- Bifurcation points characterized

**File**: `benchmark_complex_path_multilimit.m`

**Acceptance Criteria**:
- Analysis completes without divergence
- Identifies at least 1-2 additional limit points
- Smooth path navigation (no spurious jumps)
- Convergence maintained at bifurcations

---

### Benchmark 3: Arc-Length Step Size Adaptation Study
**Problem**: Snapthrough arch (variable load path complexity)  
**Parameter Study**: Vary arc-length radius $\Delta s$  

**Test Matrix**:
| Radius | Expected Steps | Convergence | Notes |
|--------|---|---|---|
| 0.01 (small) | ~100 | Slow/stable | Many steps, reliable |
| 0.05 (medium) | ~50 | Optimal | (Current Phase 26 setting) |
| 0.10 (large) | ~30 | Fast/risky | Fewer steps, may oscillate |
| 0.25 (very large) | ~15 | Unstable | May diverge near limit |

**Expected Outcome**:
- Step size radius strongly affects iteration counts and convergence
- Medium radius (0.05) offers good balance: 50 steps, 1 iter/step
- Small radius: more steps, fewer iterations per step
- Large radius: fewer steps, more iterations per step

**File**: `benchmark_arclength_radius_sensitivity.m`

**Acceptance Criteria**:
- All radius values complete analysis successfully
- Step counts follow expected pattern
- Iteration counts follow expected pattern
- Final λ values identical within 0.1%

---

### Benchmark 4: Post-Limit Instability Handling
**Geometry**: Plate with post-buckling (complex post-limit behavior)  
**Material**: Steel  
**Loading**: Push past critical load into unstable region  
**Method**: Arc-length with stress recovery  

**Expected Outcome**:
- Arc-length navigates through instability
- Stiffness matrix remains positive-definite (forced by algorithm)
- Stress field computed despite geometric instability
- Physical interpretation: shows why displacement control needed

**Reference Solution**:
- Compare with displacement-control analysis (same geometry)
- Both should reach similar final state (different paths)

**File**: `benchmark_postbuckling_instability.m`

**Acceptance Criteria**:
- Analysis completes without divergence
- Stress field computed at each step (no NaN)
- Path navigates instability gracefully
- Comparison with displacement control shows expected differences

---

## 3. Arc-Length Algorithm Documentation

### Include in Code:

1. **Riks Constraint Formulation** (ADR-003 reference):
   - Equation: modified hyperplane constraint
   - Physical: arc-length measured in extended space
   - Why: allows circumventing limit points

2. **Spherical Constraint Formulation**:
   - Equation: Euclidean distance in extended space
   - Physical: spherical ball in solution space
   - Why: simpler, less coupling between u and λ

3. **Constraint Comparison**:
   - Pros/cons of each formulation
   - Computational cost differences
   - Convergence behavior
   - When to use each

4. **Step Size Adaptation**:
   - Current: fixed radius (phase 26 verification)
   - Enhancement potential: adaptive radius based on iterations
   - Formulation: adjust Δs if iter_count > threshold

---

## 4. Success Criteria (Gate 0.5 Brief-Bind)

**You confirm that you can deliver**:
- ✓ Constraint comparison benchmark implemented by deadline
- ✓ Complex path multi-limit benchmark implemented by deadline
- ✓ Step size sensitivity study completed by deadline
- ✓ Post-limit instability benchmark implemented by deadline
- ✓ All mathematical formulations documented by deadline
- ✓ No blocking solver dependencies

---

## 5. BRIEF-BIND STATEMENT (Required before Gate 0.5)

```
[Your Name], acting as Arc-Length Specialist, confirm full responsibility for: 
(1) arc-length constraint comparison (Riks vs. spherical), (2) complex multi-limit 
path benchmark, (3) step size sensitivity study, (4) post-buckling instability 
handling, (5) algorithm documentation and formulations.

I confirm current availability and expected delivery: [date].
```

---

## 6. Questions for Clarification

- Should spherical-damping constraint attempt to call a different constraint function, or mock the results?
- For multi-limit problem, do we need to implement new geometry (cylindrical panel) or modify existing?
- Should parameter sensitivity study generate plots/comparisons, or just data collection?
- Any specific bifurcation theory to reference in documentation?

