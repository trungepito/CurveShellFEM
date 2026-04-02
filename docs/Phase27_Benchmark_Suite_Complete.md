# Phase 27 Benchmark Suite - Complete Documentation

**Phase 27 Status**: Implementation Complete ✓  
**Gate 1 Status**: AUTHORIZED ✓  
**Benchmarks**: 13 total (7 existing Phase 26 + 6 rewritten Phase 27)  
**Last Updated**: Phase 27 Launch  

---

## Table of Contents

1. [Overview](#overview)
2. [Benchmark Registry](#benchmark-registry)
3. [FEM1: Linear Benchmarks](#fem1-linear-benchmarks-2)
4. [FEM2: Nonlinear Control Benchmarks](#fem2-nonlinear-control-benchmarks-3)
5. [FEM3: Arc-Length Path Following](#fem3-arc-length-path-following-4)
6. [FEM4: Plasticity & Combined Nonlinearity](#fem4-plasticity--combined-nonlinearity-5)
7. [Phase 26 Legacy Benchmarks](#phase-26-legacy-benchmarks-7)
8. [Verification Harness](#verification-harness)
9. [Acceptance Criteria](#acceptance-criteria)
10. [Implementation Patterns](#implementation-patterns)

---

## Overview

### Purpose
Phase 27 establishes a **comprehensive benchmark suite** validating all FEM solver capabilities:
- **Linear static analysis** (FEM1)
- **Nonlinear displacement control** (FEM2)
- **Arc-length path following** (FEM3)
- **Plasticity & material nonlinearity** (FEM4)

### Team Structure
- **FEM1 Architect**: Linear benchmark design (2 benchmarks)
- **FEM2 Engineer**: Nonlinear displacement control (3 benchmarks)
- **FEM3 Specialist**: Arc-length advanced methods (4 benchmarks)
- **FEM4 Advanced**: Plasticity & combined NL (5 benchmarks)
- **VE (Verification)**: Regression harness execution
- **Scribe**: Documentation & cross-team coordination

### Architecture Pattern

All benchmarks follow a consistent structure:

```matlab
function results = benchmark_name()
    % 1. Setup: Geometry, material, loading
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.create*(...);  % Geometry
    Pre.mesh*(...);    % Mesh
    Pre.addBC(...);    % Boundary conditions
    Pre.addNodalLoad(...);  % Loads
    
    % 2. Solve: Call appropriate solver
    Sol = FEM_Solver* (Pre, opts);  % Linear, Adaptive, ArcLength, etc.
    Sol.solve(...);
    
    % 3. Extract & validate
    results.measured_value = ...;
    results.expected_value = ...;
    results.error_percent = ...;
    results.overall_pass = (error_percent < tolerance);
end
```

---

## Benchmark Registry

### Summary Table

| # | Benchmark | File | Team | Type | Purpose | Accept Criteria |
|---|-----------|------|------|------|---------|-----------------|
| **FEM1** (Linear) |
| 1 | Cantilever Linear | `benchmark_cantilever_linear.m` | FEM1 | Linear | Analytical vs FEM (Euler theory) | Disp error < 0.5% |
| 2 | Patch Test | `benchmark_patch_test.m` | FEM1 | Linear | Element formulation (const strain) | CoV < 0.5% |
| **FEM2** (Nonlinear) |
| 3 | Cantilever NL Disp Control | `benchmark_cantilever_nl_displacement_control.m` | FEM2 | Nonlinear | Disp-control, 20 steps | u_final ±5%, steps=20 |
| 4 | Quasi-Linear Weak NL | `benchmark_quasi_linear_weak_nonlinearity.m` | FEM2 | Nonlinear | Weak NL regime (u/L≪1) | Error < 1%, steps≥10 |
| 5 | Snapthrough Load Control Fail | `benchmark_snapthrough_load_control_failure.m` | FEM2 | Nonlinear | Load control divergence demo | Graceful fail at bifurcation |
| **FEM3** (Arc-Length) |
| 6 | Arc-Length Constraint Compare | `benchmark_arclength_constraint_comparison.m` | FEM3 | Arc-Length | Riks vs Spherical methods | λ_final ±1%, steps>20 |
| 7 | Complex Multi-Limit Path | `benchmark_complex_path_multilimit.m` | FEM3 | Arc-Length | Multi-limit bifurcation | Steps≥10, λ>0 |
| 8 | Arc-Length Radius Sensitivity | `benchmark_arclength_radius_sensitivity.m` | FEM3 | Arc-Length | Parametric study [0.01, 0.05, 0.10, 0.25] | Trend validation ±0.1% |
| 9 | Post-Buckling Instability | `benchmark_postbuckling_instability.m` | FEM3 | Arc-Length | Negative stiffness region | Steps>5, no divergence |
| **FEM4** (Plasticity & Combined) |
| 10 | Plasticity Cyclic | `benchmark_plasticity_cyclic.m` | FEM4 | Plasticity | Isotropic hardening (3 cycles) | Hysteresis closed, converged |
| 11 | Plasticity Elastic Region | `benchmark_plasticity_elasticregion.m` | FEM4 | Plasticity | Sub-yield (80% σ_y) | ε_p=0, converged <0.5s |
| 12 | Plasticity J2 Criterion | `benchmark_plasticity_j2criterion.m` | FEM4 | Plasticity | 3 load paths (tension, shear, biaxial) | Criterion verified |
| 13 | Plastic Geometric Combined | `benchmark_plastic_geometric_combined.m` | FEM4 | Plasticity | Combined material + geometric NL | u_final ±10%, iter≤30 |
| **Phase 26** (Legacy) |
| 14 | Snapthrough Arc-Length | `benchmark_snapthrough_arclength.m` | — | Arc-Length | Proof case (Phase 26) | λ_final ≈ 11.35 |
| 15 | Scordelis-Lo | `benchmark_scordelis_lo.m` | — | — | Shell benchmark | Deflection <2% error |
| 16+ | Others | ... | — | — | Phase 26 legacy | Maintained |

---

## FEM1: Linear Benchmarks (2)

### FEM1.1: Cantilever Linear

**File**: [benchmark_cantilever_linear.m](benchmark_cantilever_linear.m)

**Purpose**: Validate FEM linear solver via analytical comparison

**Geometry**:
- Cantilever beam: L=1m, W=0.1m, H=0.1m
- Material: E=210GPa, ν=0.3
- Load: P=1000N (vertical at tip)

**Analytical Solution** (Euler-Bernoulli):
- Deflection: δ = PL³/(3EI) ≈ 1.219 mm
- Tip stress: σ = (M_max × c)/I ≈ 6.0 MPa
- Where: I = W×H³/12 = 8.333e-5 m⁴

**Acceptance Criteria**:
- Displacement error < 0.5%
- Stress error < 1.0%

**Execution**: ~0.1s

---

### FEM1.2: Patch Test

**File**: [benchmark_patch_test.m](benchmark_patch_test.m)

**Purpose**: Validate element formulation via constant strain field

**Geometry**:
- Tensile plate: L=1m, W=1m (3×3 mesh)
- Material: E=210GPa, ν=0.3
- Loading: Uniform tension (0.1% strain = ε_xx = 0.001)

**Expected Result**: Interior stresses should be constant (uniform strain)

**Acceptance Criteria**:
- Interior element stress coefficient of variation < 0.5%
- Analytical stress = E × ε = 210 MPa

**Execution**: ~0.15s

---

## FEM2: Nonlinear Control Benchmarks (3)

### FEM2.1: Cantilever NL Displacement Control

**File**: [benchmark_cantilever_nl_displacement_control.m](benchmark_cantilever_nl_displacement_control.m)

**Purpose**: Validate nonlinear solver with prescribed displacement path

**Geometry**:
- Same cantilever as FEM1: L=1m, W=0.1m
- Geometric nonlinearity: **enabled**

**Loading**: Displacement control
- Final displacement: u_final = 0.3m (30% of span)
- Number of steps: 20 increments
- Path: Linear ramp in displacement

**Physics**:
- Geometric stiffening due to large rotations
- Reaction force increases nonlinearly with displacement

**Acceptance Criteria**:
- Final displacement within ±5% of prescribed (0.3m)
- All 20 steps complete
- Max iterations per step ≤ 20

**Execution**: ~0.5s

---

### FEM2.2: Quasi-Linear Weak Nonlinearity

**File**: [benchmark_quasi_linear_weak_nonlinearity.m](benchmark_quasi_linear_weak_nonlinearity.m)

**Purpose**: Validate solver robustness in nearly-linear regime

**Geometry**:
- Same cantilever: L=1m, W=0.1m
- Geometric nonlinearity: **enabled but effects minimal**

**Loading**: Weak load (10% of reference)
- P = 100N (vs 1000N in FEM1)
- Expected displacement: δ ≈ 0.1219 mm (very small)
- Ratio u/L ≈ 0.0001 << 1

**Physics**: Nonlinear terms are O(ε²) corrections (< 0.3%)

**Acceptance Criteria**:
- Displacement error vs linear estimate < 1%
- Steps completed ≥ 10
- Execution time < 1.0s

**Execution**: ~0.2s

---

### FEM2.3: Snapthrough Load Control Failure

**File**: [benchmark_snapthrough_load_control_failure.m](benchmark_snapthrough_load_control_failure.m)

**Purpose**: Demonstrate load control limitation at bifurcation (negative stiffness)

**Geometry**:
- Snap-through arch: R=6m, Chord=10m (same as Phase 26)
- Material: E=200GPa, ν=0.3, t=0.05m

**Loading**: Vertical point load at crown

**Expected Behavior**:
- Load control converges to limit point (λ ≈ 2.2, bifurcation)
- Unable to navigate post-bifurcation (requires arc-length)
- Adaptive solver may auto-adjust to reach stable path

**Acceptance Criteria**:
- Solver completes or gracefully diverges
- Divergence near expected bifurcation point
- Execution time < 2.0s

**Execution**: ~0.3s

**Note**: This benchmark validates **expected solver limitation**, not a bug

---

## FEM3: Arc-Length Path Following (4)

### FEM3.1: Arc-Length Constraint Comparison

**File**: [benchmark_arclength_constraint_comparison.m](benchmark_arclength_constraint_comparison.m)

**Purpose**: Compare Riks hyperplane vs Spherical arc-length constraint formulations

**Benchmarks**:
1. **Riks Constraint** (current, ADR-003):
   - Hyperplane perpendicular to solution tangent
   - Optimal convergence near bifurcation

2. **Spherical Constraint** (alternative):
   - Constant radius in (u, λ) space
   - More robust for post-buckling

**Geometry**: Same snap-through arch as FEM2.3

**Expected Results**:
- Both methods reach λ_final ≈ 11.35 (full snap-through)
- Riks: Fewer steps (more efficient)
- Spherical: More steps but equal accuracy

**Acceptance Criteria**:
- Both methods reach λ_final within ±1%
- Steps > 20 (substantial path following)
- λ difference < 1% between methods

**Execution**: ~1.0s

---

### FEM3.2: Complex Multi-Limit Path

**File**: [benchmark_complex_path_multilimit.m](benchmark_complex_path_multilimit.m)

**Purpose**: Validate arc-length navigation through multiple bifurcation points

**Geometry**:
- Cylindrical panel with initial imperfection (amplitude=0.001m)
- Creates multi-limit-point equilibrium path
- Expected bifurcations at multiple load levels

**Loading**: Radial pressure (monotone increasing)

**Physics**: Path exhibits:
- Limit point #1 (λ ≈ critical buckling)
- Secondary bifurcation (post-buckling)
- Limit point #2 (instability)

**Acceptance Criteria**:
- Steps completed ≥ 10 (navigates path)
- λ_final > 0 (forward progress)
- No divergence in multiple bifurcation region

**Execution**: ~0.8s

---

### FEM3.3: Arc-Length Radius Sensitivity

**File**: [benchmark_arclength_radius_sensitivity.m](benchmark_arclength_radius_sensitivity.m)

**Purpose**: Parametric study of arc-length radius effect on convergence

**Parameters Tested**:
- radius = 0.01 (small, many steps)
- radius = 0.05 (medium, optimal)
- radius = 0.10 (larger, fewer steps)
- radius = 0.25 (large, very few steps)

**Expected Trend**:
- Smaller radius → more steps (finer resolution)
- Larger radius → fewer steps (coarser)
- Load factor λ_final consistent across all radii (±0.1%)

**Acceptance Criteria**:
- All radii reach full path (λ_final > 10)
- λ_final consistent (±0.1%)
- Step count inversely correlated with radius

**Execution**: ~2.0s (4 radius cases)

---

### FEM3.4: Post-Buckling Instability

**File**: [benchmark_postbuckling_instability.m](benchmark_postbuckling_instability.m)

**Purpose**: Navigate post-buckling region (negative structural stiffness)

**Geometry**: Compressed plate pushed past critical load

**Loading Target**: λ=2.0 (well into post-buckling)

**Physics Challenge**:
- Tangent stiffness becomes negative (structural instability)
- Standard Newton-Raphson diverges
- Arc-length maintains solution continuity via constraint enforcement

**Acceptance Criteria**:
- Steps completed > 5
- No divergence despite negative stiffness
- λ_final > 1.0 (unstable region reached)

**Execution**: ~0.5s

---

## FEM4: Plasticity & Combined Nonlinearity (5)

### FEM4.1: Plasticity Cyclic Loading

**File**: [benchmark_plasticity_cyclic.m](benchmark_plasticity_cyclic.m)

**Purpose**: Validate isotropic hardening under cyclic loading

**Coupon Test**:
- Small element: 0.01m × 0.01m × 0.01m
- Material: σ_y = 250 MPa, H = 50 GPa (isotropic hardening)

**Loading**: 3 complete cycles
- Cycle 1: 0 → +σ → 0 (load, unload)
- Cycle 2: Same amplitude (yield strength increased via hardening)
- Cycle 3: Verification of hardening effect

**Expected Behavior**:
- Cycle 1 hysteresis area largest
- Cycles 2,3 show progressive hardening (smaller area, higher yield)
- Elastic unloading slopes all equal (E = constant)

**Acceptance Criteria**:
- Steps completed ≥ 10 (multiple cycles)
- Solution converged (Newton iterations < 20/step)
- Stress-strain path closed each cycle

**Execution**: ~0.4s

**Reference**: ADR-002 (Trial-Commit Plasticity Integration)

---

### FEM4.2: Plasticity Elastic Region

**File**: [benchmark_plasticity_elasticregion.m](benchmark_plasticity_elasticregion.m)

**Purpose**: Verify solver correctly **does not** enter plasticity below yield

**Loading**: Sub-yield stress
- Stress level: 80% × σ_y = 200 MPa (< 250 MPa yield)
- No plastic strain expected (ε_p = 0)

**Expected Behavior**:
- Stress-strain path perfectly linear (E×ε_xx)
- No plastic strain accumulation
- Execution time very fast (linear, trivial nonlinearity)
- Newton iterations = 1 per step

**Acceptance Criteria**:
- Plastic strain ε_p = 0
- Solution linear (no NL effects)
- Execution < 0.5s (fast, elastic-only)

**Execution**: ~0.2s

**Validation Purpose**: Ensures plastic criterion correctly gates plastic flow

---

### FEM4.3: Plasticity J2 Criterion

**File**: [benchmark_plasticity_j2criterion.m](benchmark_plasticity_j2criterion.m)

**Purpose**: Validate von Mises (J2) yield criterion via 3 independent load paths

**Load Path 1: Uniaxial Tension**
- σ_x: 0 → +σ_y = +250 MPa
- σ_y, σ_z: 0
- Expected yield: At σ_x = σ_y = 250 MPa

**Load Path 2: Pure Shear**
- τ_xy: 0 → +τ_yield
- J2 criterion: Yield at τ = σ_y/√3 ≈ 144 MPa
- No normal stress

**Load Path 3: Biaxial Loading**
- σ_x = σ_y: 0 → +σ
- σ_z: 0
- Expected yield: At σ = σ_y = 250 MPa (same as tension)

**Acceptance Criteria**:
- All 3 paths reach expected yield stresses
- J2 formula verified: √(3J_2) = σ_eq ≈ σ_y at yield
- Each path: steps ≥ 1 (reaches yield)

**Execution**: ~0.5s

**Validation Purpose**: Demonstrates J2 criterion implementation correctness

---

### FEM4.4: Plastic Geometric Combined

**File**: [benchmark_plastic_geometric_combined.m](benchmark_plastic_geometric_combined.m)

**Purpose**: Validate combined material + geometric nonlinearity

**Geometry**: Cantilever (same as FEM1)

**Loading**: Large displacement (u=0.2m = 20% of span)

**Material**: Low yield stress to trigger plasticity
- σ_y = 100 MPa (low, ensures plastic flow)
- H = 10 GPa (modest hardening)

**Physics**: Two NL mechanisms active simultaneously
1. **Geometric**: Large displacement/rotation
2. **Material**: Plastic yielding + hardening

**Expected Behavior**:
- High iteration counts (both NL mechanisms)
- Stress exceeds linear estimate significantly
- Permanent deformation (plastic strain) remains after unload

**Acceptance Criteria**:
- Final displacement within ±10% of prescribed (0.2m)
- Max iterations per step ≤ 30 (difficult nonlinearity)
- Steps completed ≥ 5

**Execution**: ~0.8s

**Challenge**: Demonstrates solver robustness for complex material+geometric behavior

---

## Phase 26 Legacy Benchmarks (7)

These benchmarks were established in Phase 26 and maintained for regression testing:

| # | File | Type | Purpose |
|---|------|------|---------|
| 15 | `benchmark_snapthrough_arclength.m` | Arc-Length | Snap-through, arc-length proof |
| 16 | `benchmark_scordelis_lo.m` | Shell analysis | Cylindrical shell deflection |
| 17 | `benchmark_buckling_plate.m` | Eigenvalue | Plate buckling critical load |
| 18 | `benchmark_gmnia_cylindrical_panel.m` | GMNIA | Geometric+material NL + imperfection |
| 19 | `benchmark_plastic_cantilever.m` | Plasticity | Plastic deformation (Phase 10 legacy) |
| 20 | `benchmark_plastic_snapthrough.m` | Plasticity | Combined snap-through + plasticity |
| 21 | `benchmark_shell_vibration_eigenvalue.m` | Vibration | Natural frequencies |

**Status**: Maintained from Phase 26, included in regression suite to prevent regressions

---

## Verification Harness

### File: benchmark_runner_comprehensive.m

**Role**: Verification Engineer (VE) harness for automated regression testing

**Purpose**: Execute all benchmarks and generate GATE 2 readiness report

**Execution**:
```matlab
>> summary = benchmark_runner_comprehensive();
```

**Output**:
- Individual benchmark pass/fail status
- Execution timing per benchmark
- Summary pass count (target: 13/13 for Phase 27 suite)
- GATE 2 acceptance verdict
- Baseline snapshot saved to `phase27_baseline_YYYYMMDD_HHMMSS.mat`

**GATE 2 Criteria** (all must pass):
1. ✓ All 13 benchmarks pass (overall_pass field for each)
2. ✓ No execution errors (all try-catch blocks succeed)
3. ✓ All 4 teams represented (FEM1 ✓, FEM2 ✓, FEM3 ✓, FEM4 ✓)
4. ✓ Total execution time < 120s

**Expected Result**: "GATE 2 READINESS: ✓ READY"

---

## Acceptance Criteria

### Linear Benchmarks (FEM1)

| Criterion | Metric | Tolerance | Purpose |
|-----------|--------|-----------|---------|
| Analytical Agreement | Displacement error | < 0.5% | Validates FEM solver accuracy |
| Element Formulation | Stress uniformity (CoV) | < 0.5% | Validates element basis functions |

### Nonlinear Benchmarks (FEM2)

| Criterion | Metric | Tolerance | Purpose |
|-----------|--------|-----------|---------|
| Load Step Completion | All steps converge | 100% | Validates step adaptation |
| Displacement Accuracy | Error vs prescribed | ±5% | Validates displacement control |
| Convergence Rate | Max iter/step | ≤ 20 | Validates solver robustness |
| Weak NL Detection | Error vs linear | < 1% | Validates efficiency in linear-like regime |
| Bifurcation Handling | Graceful termination | At λ_predict | Validates load-control limitation |

### Arc-Length Benchmarks (FEM3)

| Criterion | Metric | Tolerance | Purpose |
|-----------|--------|-----------|---------|
| Load Factor Accuracy | λ_final error | ±1% | Validates constraint enforcement |
| Path Resolution | Min step count | > 20 | Validates sufficient sampling |
| Constraint Equivalence | λ_diff (Riks vs Spherical) | < 1% | Validates constraint formulation |
| Bifurcation Navigation | Steps at multi-limit | ≥ 10 | Validates complex path handling |
| Post-Buckling | Steps into instability | > 5 | Validates negative stiffness management |
| Parameter Sensitivity | λ_final vs radius | ±0.1% | Validates robustness to step size |

### Plasticity Benchmarks (FEM4)

| Criterion | Metric | Tolerance | Purpose |
|-----------|--------|-----------|---------|
| Elastic Region | Plastic strain (sub-yield) | = 0 | Validates yield criterion |
| Yield Detection | Yield stress (J2) | ±2% of theory | Validates J2 formulation |
| Hardening | Stress increase (multi-cycle) | Evident | Validates hardening integration |
| Combined NL | Iteration count (combined) | ≤ 30 | Validates difficult nonlinearity handling |

### Overall GATE 2

| Criterion | Metric | Target |
|-----------|--------|--------|
| Benchmark Suite Completion | Benchmarks passing | 13/13 |
| Execution Stability | Errors during run | 0 |
| Team Coverage | Teams completing | FEM1✓ FEM2✓ FEM3✓ FEM4✓ |
| Timing Reasonableness | Total execution | < 120s |

---

## Implementation Patterns

### Pattern 1: Linear Static Analysis

```matlab
function results = benchmark_linear()
    In linear benchmarks:
    
    % Create preprocessor
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.create*(...);  % Geometry
    Pre.mesh*(...);    % Mesh
    Pre.computeNormals();
    
    % Apply BCs & loads
    Pre.addBC(..., 1:6, 0, 'Fixed');
    Pre.addNodalLoad(..., 2, P, 'Load');
    
    % Solve (linear)
    Sol = FEM_Solver(Pre);
    Sol.solveStatic();
    
    % Extract
    u = Sol.U(...);
    results.u_FEM = u;
    results.u_analytical = ...;
    results.error = abs(u - u_analytical) / u_analytical;
    results.overall_pass = (results.error < tolerance);
end
```

### Pattern 2: Nonlinear with Displacement Control

```matlab
function results = benchmark_nonlinear()
    % Create & mesh
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.create*(...); Pre.mesh*(...); Pre.computeNormals();
    
    % Apply BCs & loads (one load prescribe, one constraint)
    Pre.addBC(..., 1:6, 0, 'Fixed');
    Pre.addBC(..., 2, u_final/n_steps, 'DisprControl');
    
    % Solve (nonlinear, adaptive steps)
    opts = SolverOptions();
    opts.Tolerance = 1e-4;
    opts.InitialDt = 0.05;
    
    Sol = FEM_Solver_Adaptive(Pre, opts);
    Stage = LoadingStage(u_final);
    Stage.activateBC('Fixed');
    Stage.activateBC('DisprControl');
    Sol.solve({Stage});
    
    % Extract
    results.steps = Sol.StepCount;
    results.u_final = Sol.U(...);
    results.overall_pass = (results.steps >= min_steps);
end
```

### Pattern 3: Arc-Length Path Following

```matlab
function results = benchmark_arclength()
    % Create & mesh
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.create*(...); Pre.mesh*(...); Pre.computeNormals();
    
    % Apply BCs & loads (for load factor λ)
    Pre.addBC(..., 1:6, 0, 'Support');
    Pre.addNodalLoad(..., 3, -1.0, 'CrownLoad');  % Direction only
    
    % Solve (arc-length)
    opts = SolverOptions();
    opts.ArcLengthRadius = 0.05;
    
    Sol = FEM_Solver_ArcLength(Pre, opts);
    Stage = LoadingStage(3.0);  % λ_target = 3.0
    Stage.activateBC('Support');
    Stage.activateLoad('CrownLoad');
    Stage.ConstraintType = 'Riks';  % or 'Spherical'
    Sol.solve({Stage});
    
    % Extract
    results.lambda_final = Sol.History_Time(Sol.StepCount);
    results.overall_pass = (results.lambda_final > 2.5);
end
```

### Pattern 4: Plasticity Analysis

```matlab
function results = benchmark_plasticity()
    % Create & mesh
    Pre = FEM_Preprocessor_v2(E, nu, t);
    Pre.create*(...); Pre.mesh*(...);
    
    % Set plasticity material
    Pre.setMaterialPlastic(sigma_y, H, theta);  % yield, hardening, angle
    
    % Apply BCs & loads
    Pre.addBC(..., 1:6, 0, 'Fixed');
    Pre.addNodalLoad(..., 2, P_max, 'Load');
    
    % Solve (nonlinear with plasticity integration)
    opts = SolverOptions();
    opts.IntegrationScheme = 'ThreeStepAB';  % Per ADR-004
    
    Sol = FEM_Solver_Adaptive(Pre, opts);
    Stage = LoadingStage(P_max);
    Stage.activateBC('Fixed');
    Stage.activateLoad('Load');
    Sol.solve({Stage});
    
    % Extract plastic strains (if available in solution)
    results.plastic_strain = Sol.Ep(...);  % or compute from history
    results.overall_pass = (abs(results.plastic_strain) > epsilon_min);  % or similar
end
```

---

## Quick Reference

### Execution Commands

```matlab
% Run single benchmark
result = benchmark_cantilever_linear();

% Run all benchmarks (VE harness)
summary = benchmark_runner_comprehensive();

% Check individual results
fprintf('FEM1.1 Pass: %s\n', iif(result.overall_pass, 'YES', 'NO'));

% Access baseline
load phase27_baseline_*.mat;
fprintf('Total benchmarks passed: %d / %d\n', summary.pass_count, summary.total_benchmarks);
```

### Expected Execution Time

- FEM1 benchmarks: ~0.3s total
- FEM2 benchmarks: ~1.0s total
- FEM3 benchmarks: ~3.0s total
- FEM4 benchmarks: ~2.0s total
- **Phase 27 Total**: ~6-8 seconds
- **Full Suite (with Phase 26)**: ~15-20 seconds

### Common Troubleshooting

| Issue | Solution |
|-------|----------|
| "Undefined variable: FEM_Solver_Adaptive" | Ensure `src/` folder in path: `addpath('src')` |
| Benchmark fails on file load | Run from project root directory |
| Arc-length diverges | Reduce `opts.ArcLengthRadius` (try 0.01) |
| Plasticity gives wrong answer | Verify `Pre.setMaterialPlastic()` called before solve |

---

## Glossary

- **ADR-002**: Trial-Commit plasticity stress integration (Phase 10)
- **ADR-003**: Riks arc-length hyperplane constraint (Phase 26)
- **ADR-004**: Integration scheme 2×2×5 (Phase 26)
- **VE**: Verification Engineer (team role, artifact → regression harness)
- **Scribe**: Documentation coordinator (team role)
- **GATE 2**: Readiness review (all benchmarks passing, regression harness validated)
- **LoadingStage**: Modern API for stage-based problem definition (replaces procedural API)
- **FEM_Preprocessor_v2**: Mesh generation and BC/load application
- **FEM_Solver**: Linear stiffness solver
- **FEM_Solver_Adaptive**: Nonlinear solver with adaptive stepping
- **FEM_Solver_ArcLength**: Path-following solver (Riks, Spherical)

---

**Phase 27 Documentation Package**  
Generated for GATE 1 Authorization → GATE 2 Readiness Transition  
Scribe: Documentation Coordinator  
Last Updated: Phase 27 Launch
