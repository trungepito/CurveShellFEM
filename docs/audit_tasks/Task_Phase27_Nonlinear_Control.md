# Phase 27 | Task Brief: Nonlinear Control Benchmarks (FEM Engineer)
**Date**: 2026-03-31  
**Phase**: 27 (Comprehensive Benchmark Suite)  
**Role**: Nonlinear Control Specialist (FEM Engineer)  
**Gate**: 0 → 0.5 (Awaiting Brief-Bind)

---

## 1. Objective (VERBATIM FROM PHASE 27 ASSEMBLY)

"Implement load- and displacement-control benchmarks for nonlinear analysis validation. Your responsibility is to: (1) Create cantilever beam with geometric nonlinearity (compare load vs. displacement control), (2) Implement snapthrough problem with load control to demonstrate limit point constraints, (3) Develop quasi-linear benchmark for convergence validation, (4) Compare solver robustness across control methods, (5) Document control method advantages/limitations with mathematical derivation."

---

## 2. Your Deliverables

### Benchmark 1: Cantilever with Geometric Nonlinearity (Displacement Control)
**Geometry**: 3m cantilever, thin-walled section  
**Material**: Steel (E=200 GPa, ν=0.3)  
**Loading**: Increasing tip displacement (δ = 0 to 1.5m)  
**Method**: Displacement control (prescribe tip displacement)  

**Expected Outcome**:
- Load-displacement curve shows nonlinear stiffening (geometric effects)
- Tip reaction force increases nonlinearly with displacement
- Von Mises stress field shows complex nonlinear distribution
- Convergence: Newton iterations increase as nonlinearity grows (3-4 early, 8-12 later)

**Reference Solution**:
- Compare with load-controlled analysis (same problem, load increments)
- Displacement control should reach larger deflections (load control stops at limit)
- Energy conservation check: $W_{external} = U_{elastic} + U_{geometric}$

**File**: `benchmark_cantilever_nlgeom_dispcontrol.m`

**Acceptance Criteria**:
- Displacement control reaches δ = 1.5m without divergence
- Load-displacement curve is monotonically increasing or shows expected nonlinearity
- Convergence rate: 4-8 iterations per step (acceptable for large displacement)
- Energy balance error: < 0.5% (numerical integration accuracy)

---

### Benchmark 2: Load Control Failure (Snapthrough with Load Control)
**Geometry**: Shallow arch (same as Phase 26 snapthrough)  
**Material**: Steel (standard)  
**Loading**: Vertical load at apex (F = 0 to 3000 N in equal increments)  
**Method**: Load control (constant load increment)  

**Expected Outcome**:
- Load control FAILS at limit point
- Analysis diverges when tangent stiffness becomes negative (snap-through region)
- Demonstrates load control cannot follow post-limit path
- Expected failure load: ~2200 N (limit point)
- Solver message: "Divergence unavoidable" or similar

**Reference Solution**:
- Compare with arc-length solution (Phase 26 existing benchmark)
- Arc-length reaches λ ≈ 11.35
- Load control maximum: λ ≈ 2.2 (only ~19% of arc-length path)

**File**: `benchmark_snapthrough_loadcontrol.m`

**Acceptance Criteria**:
- Analysis completes without error (controlled divergence handling)
- Failure occurs near expected limit point (±10% tolerance)
- Diagnostic message indicates divergence (not solver crash)
- Can be rerun without MATLAB restart

---

### Benchmark 3: Quasi-Linear Problem (Weak Nonlinearity Convergence)
**Geometry**: Plate with small deflection (δ/h < 1, where h = thickness)  
**Material**: Aluminum (E=70 GPa, ν=0.3)  
**Loading**: Transverse pressure (p = 10 kPa, small enough for weak NL)  
**Method**: Nonlinear solver with Newton-Raphson  

**Expected Outcome**:
- Nonlinear stiffness effects are small (< 5% deviation from linear)
- Newton method converges in 1-2 iterations per step (quadratic convergence)
- Load-displacement curve nearly linear
- This validates convergence behavior for problem classes where nonlinearity is weak

**Reference Solution**:
- Compare with linear analysis (same problem, small displacement assumption)
- Nonlinear result should differ by < 5% at peak load
- Curvature should be minimal (subtle nonlinearity)

**File**: `benchmark_quasilinear_convergence.m`

**Acceptance Criteria**:
- Newton iterations: 1-2 per step (highly efficient convergence)
- Nonlinear result within 5% of linear result
- Load-displacement curve shows minimal curvature
- Validates solver efficiency on "nearly linear" problems

---

### Benchmark 4: Control Method Comparison Report
**Deliverable**: Comparative analysis document  

**Contents**:
1. **Load Control**:
   - Efficiency: iterations per step
   - Limitation: maximum load reached (limit point)
   - Use case: Small displacement problems

2. **Displacement Control**:
   - Efficiency: iterations per step (may be higher)
   - Advantage: can pass through limit points
   - Use case: Large displacement, snap-through

3. **Arc-Length** (reference):
   - Efficiency: iterations per step
   - Advantage: automatic step sizing, handles complex paths
   - Use case: Complex paths, multiple limit points

4. **Mathematical Formulation**:
   - Define each control method (constraint equation)
   - Show how constraint modifies Newton update
   - Explain geometric interpretation

---

## 3. Benchmark Design Responsibilities

### Load-Displacement Curve Documentation

For each benchmark, your implementation should:
1. **Compute load-displacement data**: Store F(displacement) or λ(displacement)
2. **Record convergence history**: Iterations per step
3. **Plot results**: Load-displacement curve + convergence rate
4. **Compare with references**: Show error vs. analytical or arc-length solution

### Control Method Implementation

Ensure all benchmarks use proper control methods:
- **Displacement Control**: `LoadingStage` with `setDisplacementControl()`
- **Load Control**: `LoadingStage` with `setLoadControl()`
- **Arc-Length**: Use `FEM_Solver_ArcLength` for reference

---

## 4. Mathematical Formulation (Include in Code)

### Load Control Constraint
$$\lambda(t) = \lambda_{ref} \cdot (1 + \alpha \cdot n)$$
where $\alpha$ is step increment, $n$ is step number

### Displacement Control Constraint  
$$u_i(t) = u_{ref} \cdot (1 + \alpha \cdot n)$$
for prescribed DOF $i$

### Modified Newton System
Load control:  
$$[K_T] \Delta u = F - F_n + \lambda \Delta F_{ref}$$

Displacement control:  
$$[\tilde{K}_T] \Delta u = F - F_n$$  
with constraint: $u_{prescribed} = u_{target}$

---

## 5. Success Criteria (Gate 0.5 Brief-Bind)

**You confirm that you can deliver**:
- ✓ All 4 control benchmarks implemented by deadline
- ✓ Comparative analysis document with formulations by deadline
- ✓ All convergence data (iterations, error metrics) recorded by deadline
- ✓ Plots and visualization ready for final report by deadline
- ✓ No blocking solver dependencies

---

## 6. BRIEF-BIND STATEMENT (Required before Gate 0.5)

Please respond confirming:

```
[Your Name], acting as Nonlinear Control Specialist, confirm full responsibility for: 
(1) displacement-control cantilever benchmark, (2) load-control snapthrough failure 
validation, (3) quasi-linear convergence benchmark, (4) comparative analysis of control 
methods with mathematical formulation.

I confirm current availability and expected delivery: [date].
```

---

## 7. Questions for Clarification

- Should load control analysis attempt to continue past divergence (e.g., with step bisection)?
- For quasi-linear benchmark, what maximum nonlinearity level (% stiffness change) is acceptable?
- Should benchmarks use existing geometries (e.g., snapthrough arch) or new geometries?
- Any specific control parameters or solver tolerances I should use?

