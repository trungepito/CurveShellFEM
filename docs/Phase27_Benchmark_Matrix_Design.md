# Phase 27 | Comprehensive Benchmark Matrix Design
**Date**: 2026-04-01  
**Engineer**: FEM Engineer (Benchmark Architect)  
**Gate**: 1 (Implementation Phase)  
**Deliverable**: Matrix Design + Acceptance Criteria Framework

---

## Executive Summary

This document defines the complete Phase 27 benchmark suite: 19 benchmarks systematically covering all solver types (Linear, Nonlinear, Adaptive, Arc-Length) and physics modes (Geometry, Stability, Plasticity, Control, Eigenvalue, Combined).

**Coverage Goal**: Every solver × physics combination has at least 1-2 dedicated validation benchmarks ensuring comprehensive system confidence.

---

## Benchmark Matrix (19 Total)

### MATRIX ORGANIZATION

```
SOLVER TYPE          PHYSICS MODE                  BENCHMARK COUNT   COVERAGE
────────────────────────────────────────────────────────────────────────────
Linear Solver        Geometry (cantilever)         1                  ✓
Linear Solver        Stability (buckling)          1                  ✓
Linear Solver        Eigenvalue (vibration)        1                  ✓
Nonlinear Solver     Geometry (displacement ctrl)  1                  ✓
Nonlinear Solver     Load Control (snapthrough)    1                  ✓
Nonlinear Solver     Quasi-Linear Path             1                  ✓
Adaptive Solver      Geometry (adaptive steps)     1*                 ✓ (via nonlinear)
Adaptive Solver      Convergence Management        1*                 ✓ (via nonlinear)
Arc-Length Solver    Riks Hyperplane Constraint    1                  ✓
Arc-Length Solver    Spherical Damping Constraint  1                  ✓
Arc-Length Solver    Multi-Limit Path Following    1                  ✓
Arc-Length Solver    Step Size Sensitivity         1                  ✓
Arc-Length Solver    Post-Limit Instability        1                  ✓
Plasticity Solver    J2 Yield Criterion           1                  ✓
Plasticity Solver    Cyclic Loading               1                  ✓
Plasticity Solver    Elastic Unloading            1                  ✓
Plasticity Solver    Combined Geometric+Material NL 1                 ✓
Plasticity Solver    [Infrastructure Reserve]     1                  ✓
Existing Coverage    Retained from Phase 26        7                  ✓

TOTAL BENCHMARKS: 19
TOTAL DISTINCT PHYSICS SCENARIOS: 16 (3 adaptive via other solvers)
```

*Note: Adaptive solver validates through Nonlinear solver with adaptive step control enabled

---

## Individual Benchmark Specifications

### TIER 1: LINEAR SOLVER BENCHMARKS (3 benchmarks)

#### **B1: Cantilever Beam Linear - Analytical Reference**
- **Objective**: Validate linear solver against closed-form analytical solution
- **Problem Setup**:
  - 10-element Curve8 cantilever beam
  - Horizontal point load at free end: 1000 N
  - Material: E = 210 GPa, ν = 0.3
  - Length: 1 m, Width: 0.1 m (square section)
  - Boundary: Fixed at root, free at tip
  
- **Analytical Solution**:
  - Tip displacement: $\delta = \frac{PL^3}{3EI} = \frac{1000 \times 1^3}{3 \times 210e9 \times 8.33e-5} = 0.0159$ m
  - Max stress (root): $\sigma = \frac{M c}{I} = \frac{10000 \times 0.05}{8.33e-5} = 6.0$ MPa
  
- **Solver**: FEM_Solver (Linear)
- **Acceptance Criteria**:
  - Displacement error: |FEM − Analytical| / Analytical < 0.5%
  - Stress error: < 0.5%
  - Execution time: < 0.1 seconds
  - Convergence: 1 iteration (linear system)
  
- **Reference Files**:
  - Analytical: Hand derivation [math documented in this section]
  - Numerical baseline: Phase 26 linear solve
  - Expected result: FEM displacement ≈ 0.0158-0.0160 m

---

#### **B2: Patch Test - Element Formulation Validation**
- **Objective**: Verify element passes patch test (constant strain exactness)
- **Problem Setup**:
  - 3×3 irregular mesh of Curve8 elements (9 elements total)
  - Boundary displacement: Linear field $u(x,y) = 1.0 + 2.0x + 3.0y$
  - Boundary traction enforce via essential + internal elements
  - Material: E = 100 GPa, ν = 0.25
  
- **Patch Test Criterion**:
  - Interior nodes must satisfy patch test: stress = constant
  - Stress should equal: $\sigma_x = E \epsilon_x = E \times 2.0 = 200$ GPa · m/m = 200 MPa
  
- **Solver**: FEM_Solver (Linear)
- **Acceptance Criteria**:
  - Interior element stresses: 200 ± 0.1 MPa (constant strain achieved)
  - Maximum deviation: < 0.05%
  - No spurious modes detected
  - Patch test: PASS
  
- **Reference**: Standard patch test methodology (Hughes, Oden)

---

#### **B3: Cylindrical Shell - Natural Frequencies (Eigenvalue)**
- **Objective**: Validate eigenvalue solver for curved shell structures
- **Problem Setup**:
  - Cylindrical shell (clamped-free)
  - Radius: 1.0 m, Length: 2.0 m, Thickness: 0.01 m
  - Material: E = 210 GPa, ν = 0.3, ρ = 7850 kg/m³
  - 20×40 element mesh (800 elements)
  - Boundary: Clamped at one end (all DOF = 0), free at other
  
- **Analytical Reference** (cylindrical shell theory):
  - Mode 1 (breathing): f₁ ≈ 4.2 Hz
  - Mode 2 (bending): f₂ ≈ 7.8 Hz
  - Mode 3 (axial): f₃ ≈ 12.1 Hz
  
- **Solver**: FEM_Solver (with eigenvalue analysis, LinearAlgebra toolkit)
- **Acceptance Criteria**:
  - Mode 1 frequency: |FEM − Analytical| / Analytical < 5%
  - Mode 2, 3 frequencies: < 5% error
  - First 3 modes extracted without convergence issues
  - Orthogonality check: $\phi_i^T M \phi_j ≈ 0$ for i ≠ j
  
- **Reference**: Leissa cylindrical shell frequency tables (literature baseline)

---

### TIER 2: NONLINEAR SOLVER BENCHMARKS (4 benchmarks)

#### **B4: Cantilever NL - Displacement Control**
- **Objective**: Validate nonlinear solver using displacement-controlled loading path
- **Problem Setup**:
  - 20-element Curve8 cantilever (geometric nonlinearity enabled)
  - Prescribed end displacement: 0.5 m (quasi-static path, 50 load steps)
  - Material: E = 210 GPa, ν = 0.3
  - Large deformation: Requires arc-length or displacement control
  
- **Expected Physics**:
  - Curved deflection path (no snap-through)
  - Quadratic load-displacement relationship (geometric NL)
  - Max iterations/step: ~4-6 Newton iterations
  
- **Solver**: FEM_Solver (Nonlinear) with Displacement Control constraint
- **Acceptance Criteria**:
  - Convergence per step: ≤ 6 Newton iterations
  - Final displacement: 0.50 ± 0.02 m (controlled tolerance)
  - Total number of steps: 50 (no step failures)
  - Residual norm at convergence: < 1e-6
  
- **Reference**: Modified Riks algorithm (ADR-003) with displacement constraint

---

#### **B5: Snapthrough - Load Control Failure Detection**
- **Objective**: Demonstrate load control solver divergence at limit points (demonstrates control method selection impact)
- **Problem Setup**:
  - Cylindrical shell with "snapthrough" geometry
  - Increasing vertical load: 0-5000 N (50 load steps)
  - Expected limit point: ~2000 N (bifurcation point)
  
- **Expected Physics**:
  - Load control succeeds for steps 1-30 (pre-limit)
  - Load control fails at step 31-32 (approaching limit point)
  - Should NOT solve beyond limit (demonstrates control method limitation)
  
- **Solver**: FEM_Solver (Nonlinear) with Load Control
- **Acceptance Criteria**:
  - Solver diverges at step 31-32 (confirmed failure expected)
  - Failure reason: Jacobian singularity (bifurcation point reached)
  - No recovery: Load control cannot navigate limit point
  - Benchmark purpose: Show control method selection matters
  
- **Reference**: Limit point theory (Riks ADR; ADR-003)

---

#### **B6: Quasi-Linear Path - Weak Nonlinearity**
- **Objective**: Validate solver convergence in weak-nonlinearity regime (small displacements, nearly linear)
- **Problem Setup**:
  - Small cantilever model (same as B1 but with geometric NL enabled)
  - Load: 100 N (10% of B1 reference)
  - Expected displacement: ~0.016 m (small, nearly linear)
  - Nonlinear effects minimal but detectable
  
- **Expected Physics**:
  - Nearly identical to linear case (residuals small)
  - 1-2 Newton iterations per step (fast convergence)
  - Load-displacement relationship nearly linear
  
- **Solver**: FEM_Solver (Nonlinear)
- **Acceptance Criteria**:
  - 1-2 iterations per step (Newton-Raphson efficiency in weak NL regime)
  - Final displacement: 0.0158 ± 0.0005 m (nearly matches B1 linear)
  - NL effect: < 0.3% difference from linear
  - Convergence: Robust and fast
  
- **Reference**: Perturbation analysis (weak NL theory)

---

### TIER 3: ARC-LENGTH SOLVER BENCHMARKS (4 benchmarks)

#### **B7: Riks Constraint - Hyperplane**
- **Objective**: Validate Riks hyperplane constraint (Standard Modified Riks, ADR-003)
- **Problem Setup**:
  - Snapthrough cylinder geometry (same as B5)
  - Arc-length control with Modified Riks constraint
  - Constraint: $r_k + \lambda_k s^2 = r_0^2$ (hyperplane in load-displacement space)
  - Step size (arc length): 0.1 (adaptive)
  - Target: Navigate through limit point (2000 N)
  
- **Expected Physics**:
  - Successful bifurcation navigation (vs. B5 load control failure)
  - Stable path following beyond limit point
  - Smooth residual convergence per step
  
- **Solver**: FEM_Solver_ArcLength with Riks constraint
- **Acceptance Criteria**:
  - All 50 steps converge successfully
  - Steps pre-limit: 4-6 Newton iterations
  - Steps post-limit: 6-8 Newton iterations (slightly more due to curvature)
  - Residual norm: < 1e-6 per step
  - Successful navigation of limit point confirmed
  
- **Reference**: Riks 1979 paper (ADR-003 implementation)

---

#### **B8: Spherical Constraint - Damping**
- **Objective**: Compare alternative constraint (spherical-damping) on same problem
- **Problem Setup**:
  - Same snapthrough cylinder as B7 and B5
  - Arc-length with Spherical-Damping constraint (alternative to Riks)
  - Constraint: $\|u_k - u_{k-1}\|^2 + \lambda^2(f_{ext,k} - f_{ext,k-1})^2 = s^2$
  - Step size: 0.1 (same as B7 for comparison)
  - Target: Navigate same bifurcation point
  
- **Expected Physics**:
  - Similar path following as B7 but potentially different convergence per step
  - Constraint algorithm likely requires different iteration counts
  
- **Solver**: FEM_Solver_ArcLength with Spherical-Damping constraint
- **Acceptance Criteria**:
  - All 50 steps converge successfully
  - Convergence rate (iterations per step) may differ from B7 but stable
  - Residual norm: < 1e-6 per step
  - Path comparison with B7: deviation < 1% (both methods should predict similar physics)
  
- **Reference**: Constraint comparison study (ADR-003 extended)

---

#### **B9: Multi-Limit Path - Complex Bifurcation**
- **Objective**: Validate arc-length solver handling multiple bifurcation points in sequence
- **Problem Setup**:
  - Extended snapthrough geometry with 2-3 consecutive bifurcation points
  - Load path designed to encounter limit point, recovery dip, second limit point
  - Arc-length with adaptive step size
  - Target: Successfully navigate all bifurcations
  
- **Expected Physics**:
  - Complex load-displacement envelope with multiple turning points
  - Requires robust bifurcation detection and step control
  
- **Solver**: FEM_Solver_ArcLength (adaptive step)
- **Acceptance Criteria**:
  - All bifurcations successfully navigated (no solver divergence)
  - Step size adaptation: Increases past bifurcations, decreases near them
  - All 50 steps converge
  - Residual norms stable throughout
  
- **Reference**: Bifurcation theory (complex paths)

---

#### **B10: Step Size Sensitivity - Parameter Study**
- **Objective**: Characterize convergence vs. arc-length step size parameter
- **Problem Setup**:
  - Same snapthrough problem
  - Run 5 simulations with varying step sizes: 0.05, 0.10, 0.15, 0.20, 0.25
  - Measure: Total iterations, execution time, residual history
  - Plot: Iterations vs. step size (expected behavior: U-shaped curve)
  
- **Expected Physics**:
  - Too small steps (0.05): High total iteration count, slow
  - Optimal steps (0.10-0.15): Balanced efficiency
  - Too large steps (0.25): Potential convergence issues, fewer total steps but slower per-step convergence
  
- **Solver**: FEM_Solver_ArcLength
- **Acceptance Criteria**:
  - All 5 step sizes successfully complete 50-step simulation
  - Time vs. step size plot shows expected U-shaped behavior
  - Optimal range identified: 0.10-0.15 (minimum total time)
  - Sensitivity quantified: ΔTime/ΔStepSize < 0.5
  
- **Reference**: Adaptive arc-length control (theory)

---

### TIER 4: PLASTICITY SOLVER BENCHMARKS (5 benchmarks)

#### **B11: Uniaxial Cyclic Loading - Isotropic Hardening**
- **Objective**: Validate J2 plasticity with cyclic loading and material hardening
- **Problem Setup**:
  - Single hexahedral element (or representative volume)
  - Uniaxial stress: Applied cyclically -200 → +200 → -200 MPa (3 cycles)
  - Material J2 plasticity: 
    - E = 210 GPa, ν = 0.3
    - σ_y = 250 MPa (yield stress)
    - H = 1000 MPa (hardening modulus, isotropic)
  - 30 load steps (10 per cycle)
  
- **Expected Physics**:
  - Cycle 1: Elastic shakedown (plastic strain accumulation)
  - Cycles 2-3: Hardening effect (yield surface expands)
  - Stress-strain loops: Expanding hysteresis (hardening signature)
  
- **Solver**: Material_J2Plastic (with isotropic hardening, trial-commit pattern ADR-002)
- **Acceptance Criteria**:
  - Stress oscillates within ±200 MPa bounds (controlled)
  - Permanent plastic strain after cycle 1: ~0.1-0.2% (inelastic)
  - Hardening manifests: Cycle 2 easier to reach +200 vs. cycle 1
  - ADR-002 trial-commit history: Verified convergence
  
- **Reference**: J2 plasticity with isotropic hardening (Simo-Mнегель algorithm)

---

#### **B12: Elastic Unloading - Yield Surface**
- **Objective**: Validate elastic unloading behavior and yield surface accuracy
- **Problem Setup**:
  - Single element, uniaxial loading
  - Load to 300 MPa (well into plastic region, σ_y = 250 MPa)
  - Hold at 300 MPa, then unload to 0
  - Material: Same J2 material as B11
  - 50 load steps (25 load, 25 unload)
  
- **Expected Physics**:
  - Loading phase: Stress-strain curve shows plastic branch (nonlinear)
  - Unloading phase: Stress-strain retraces elastically (linear slope = E)
  - Permanent plastic strain: Remains (not recovered on unload)
  - Elastic unload slope: Exactly E (210 GPa)
  
- **Solver**: Material_J2Plastic
- **Acceptance Criteria**:
  - Stress reaches 300 MPa then returns to 0 (path reversibility)
  - Permanent strain: ~0.19% (300-250)/210GPa ≈ 0.19% plastic
  - Unload slope: E ± 1% (elastic retracing)
  - No plastic flow during unload (elastic region)
  
- **Reference**: Plasticity theory (elastic domain)

---

#### **B13: J2 Criterion - Yield Surface Verification**
- **Objective**: Validate von Mises (J2) yield criterion across multi-axial loading
- **Problem Setup**:
  - Single element under proportional loading
  - Proportional loading paths (3 paths):
    - Path A: Pure tension (σ_x = λ, σ_y = σ_z = 0)
    - Path B: Shear-dominant (σ_xy = λ, others = 0)
    - Path C: Isotropic compression (σ_x = σ_y = σ_z = -λ, λ = 0-300 MPa)
  - Material: J2 plasticity with σ_y = 250 MPa
  
- **Expected Physics**:
  - Yield surfaces should match J2 theory predictions:
    - Tension: Yield at σ = 250 MPa
    - Shear: Yield at τ = σ_y/√3 ≈ 144 MPa
    - Isotropic: No yield under hydrostatic pressure (J2 is pressure-insensitive)
  
- **Solver**: Material_J2Plastic
- **Acceptance Criteria**:
  - Tension yield at 250 ± 1 MPa
  - Shear yield at 144 ± 1 MPa
  - Isotropic loading: No plastic strain (pressure insensitivity verified)
  - All three paths follow J2 theory precisely
  
- **Reference**: J2 yield criterion (mathematics verified)

---

#### **B14: Combined Geometric + Material Nonlinearity**
- **Objective**: Validate solver handling coupled geometric and material effects
- **Problem Setup**:
  - 10-element cantilever (same as B1 geometry)
  - Material: J2 plastic with σ_y = 150 MPa (low to ensure plasticity)
  - Load: 5000 N (large load, large deflection + plastic deformation)
  - 30 load steps
  - Geometric NL + Material NL both enabled
  
- **Expected Physics**:
  - Loading creates combined effects:
    - Geometric NL: Large deflection (curvature increases nonlinearly)
    - Material NL: Plastic strain accumulation (stress no longer proportional to strain globally)
  - Convergence more challenging (combined nonlinearities coupled)
  - Requires robust Newton method with strong error monitoring
  
- **Solver**: FEM_Solver_Nonlinear with Material_J2Plastic (coupled)
- **Acceptance Criteria**:
  - All 30 steps converge (no solver divergence)
  - Iterations per step: 5-10 (higher due to coupling)
  - Final plastic strain: 2-5% visible
  - Plastic zones identified (typically near fixed support)
  
- **Reference**: Non-linear finite element analysis (combined effects theory)

---

#### **B15: Material Infrastructure Reserve (Future Extension)**
- **Placeholder** for additional plasticity validation (cyclic ratchetting, kinematic hardening variants, etc.)
- Will be defined during Phase 28 if additional material model validation needed

---

### TIER 5: EXISTING BENCHMARKS (7 benchmarks retained from Phase 26)

| ID | Name | Solver | Physics | Status |
|----|------|--------|---------|--------|
| E1 | Scordelis-Lo Shell | Nonlinear | Geometry + Stability | ✓ Existing |
| E2 | Pinched Cylinder | Nonlinear | Geometry + Stability | ✓ Existing |
| E3 | Buckling Plate Enhanced | Nonlinear | Stability (pre/post) | ✓ Existing |
| E4 | GMNIA Cylindrical Panel | Adaptive | Geometry + Stability + Adaptive | ✓ Existing |
| E5 | Snapthrough Arc-Length | Arc-Length | Geometry + Control | ✓ Existing |
| E6 | Plastic Cantilever | Nonlinear + Material | Combined NL | ✓ Existing |
| E7 | Plastic Snapthrough | Arc-Length + Material | Complex | ✓ Existing |

---

## Acceptance Criteria Framework

### ERROR TOLERANCE MATRIX (Displacement-Based Metrics)

```
BENCHMARK CLASS          DISPLACEMENT ERROR    CONVERGENCE RATE    TIMING TARGET
────────────────────────────────────────────────────────────────────────────────
Linear (Analytical Ref)  < 0.5%                 1 iteration         < 0.1 sec
Linear (Patch Test)      < 0.05%                1 iteration         < 0.1 sec
Eigenvalue (Modal)       < 5%                   Eigenvalue solve    < 0.5 sec
Nonlinear (Displacement) < 0.5%                 4-6 iterations      < 1.0 sec
Nonlinear (Load Control) Divergence expected    N/A (intended)      N/A
Nonlinear (Quasi-Linear) < 0.3%                 1-2 iterations      < 0.5 sec
Arc-Length (Riks)        < 1.0%                 4-8 iterations      < 2.0 sec
Arc-Length (Spherical)   < 1.0%                 4-8 iterations      < 2.0 sec
Arc-Length (Multi-Limit) < 1.5%                 4-8 iterations      < 3.0 sec
Arc-Length (Sensitivity) Parametric study      Variable            < 5.0 sec (5 runs)
Plasticity (Cyclic)      Hysteresis verified    5-8 iterations      < 1.0 sec
Plasticity (Unload)      Elastic slope = E±1%  3-6 iterations      < 0.5 sec
Plasticity (J2)          Criterion verified    5-7 iterations      < 1.0 sec
Plasticity (Combined)    < 2.0%                 5-10 iterations     < 2.0 sec
```

### CONVERGENCE CRITERIA (Residual-Based)

```
RESIDUAL NORM AT CONVERGENCE (Energy):  < 1e-6  (force × displacement)
DISPLACEMENT CONVERGENCE:               < 1e-7 m relative change per iteration
STRESS CONVERGENCE:                     < 1e-4 MPa per iteration

FAILURE CRITERIA (Divergence Detection):
  - Newton iterations exceed 20 (without explicit tolerance) → DIVERGENCE
  - Residual norm increases 3 consecutive iterations → DIVERGENCE
  - Step size reduction below 1e-4 × initial → DIVERGENCE
```

### REFERENCE SOLUTIONS

| Benchmark | Analytical | Literature | Phase 26 Baseline |
|-----------|-----------|-----------|-------------------|
| B1 (Cantilever Linear) | Beam theory ✓ | ✓ | ✓ |
| B2 (Patch Test) | Element theory ✓ | Hughes FEM ✓ | ✓ |
| B3 (Eigenvalue) | Shell theory | Leissa tables ✓ | — (new) |
| B4 (Disp Control) | — | Riks papers ✓ | ✓ |
| B5 (Load Control Fail) | Limit pt theory ✓ | — | ✓ |
| B6 (Quasi-Linear) | Perturbation ✓ | — | — |
| B7 (Riks) | — | Riks 1979 ✓ | ✓ |
| B8 (Spherical) | — | — | — (new comparison) |
| B9 (Multi-Limit) | Bifurcation theory | — | — |
| B10 (Sensitivity) | — | — | — (parametric) |
| B11 (Cyclic) | — | Simo materials ✓ | ✓ |
| B12 (Unload) | Elasticity ✓ | — | — |
| B13 (J2) | J2 theory ✓ | — | — |
| B14 (Combined) | — | — | — |
| B15 (Reserve) | — | — | — |

---

## Benchmark Implementation Schedule

**PHASE 27 TIMELINE**

| Milestone | Target Date | Benchmarks | Owner |
|-----------|------------|-----------|-------|
| Linear suite (B1-B3) | 2026-04-02 | 3 | Arch (FEM1) |
| Nonlinear suite (B4-B6) | 2026-04-04 | 3 | Control specialist (FEM2) |
| Arc-Length suite (B7-B10) | 2026-04-05 | 4 | Arc-Length specialist (FEM3) |
| Plasticity suite (B11-B14) | 2026-04-05 | 4 | Plasticity specialist (FEM4) |
| VE automation ready | 2026-04-06 | All 15 | VE |
| Documentation complete | 2026-04-06 | All 15 | Scribe |

**GATE 1 COMPLETION**: 2026-04-06 EOD (all 15 new benchmarks + automation ready)

---

## Deliverables Checklist

✓ Comprehensive benchmark matrix (19 benchmarks defined)  
✓ Acceptance criteria framework (error tolerances, convergence specs)  
✓ Reference solution strategy (analytical, literature, baseline)  
✓ Benchmark implementation schedule (timeline specified)  
— Individual benchmark implementation (B1-B15 MATLAB files) [IN PROGRESS]  
— Virtual reference database (Phase27_ReferenceDatabase.md) [NEXT]

