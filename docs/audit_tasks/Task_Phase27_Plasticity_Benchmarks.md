# Phase 27 | Task Brief: Plasticity Benchmarks (FEM Engineer)
**Date**: 2026-03-31  
**Phase**: 27 (Comprehensive Benchmark Suite)  
**Role**: Plasticity Specialist (FEM Engineer)  
**Gate**: 0 → 0.5 (Awaiting Brief-Bind)

---

## 1. Objective

"Implement material plasticity and J2 flow benchmarks for comprehensive solver validation. Your responsibility is to: (1) Create cyclic loading problem validating hardening/softening behavior, (2) Implement elastic unloading benchmark (verify yield surface), (3) Develop J2 plasticity validation problem with analytical reference, (4) Create combined geometric + material NL benchmark, (5) Document material model formulations and stress integration schemes (ADR-002: trial-commit history)."

---

## 2. Your Deliverables

### Benchmark 1: Uniaxial Cyclic Loading (Hardening/Softening)
**Geometry**: Small square domain (1m × 1m × 0.1m), single element or few elements  
**Material**: Steel with isotropic hardening (yield: σ_y = 250 MPa, hardening: H = 50 GPa)  
**Loading**: Cyclic uniaxial tension  
- Cycle 1: ε = 0 to 1% and back to 0
- Cycle 2: ε = 0 to 1.5% and back to 0
- Cycle 3: ε = 0 to 2% and back to 0

**Expected Outcome**:
- Cycle 1: Elastic → plastic yield → elastic unload → closed hysteresis loop
- Cycle 2: Smaller yield point due to hardening, larger loop (higher inelastic strain)
- Cycle 3: Further hardening, even larger loop
- All unloading is elastic (return to elastic modulus slope)
- Demonstrate memory effect (hardening material)

**Reference Solution**:
- J2 flow rule with isotropic hardening
- σ_y(cycle) = σ_y,0 + H × (cumulative plastic strain)
- Hysteresis energy dissipation per cycle

**File**: `benchmark_plasticity_cyclic.m`

**Acceptance Criteria**:
- Hysteresis loops close correctly
- Yield strength increases with each cycle (hardening evident)
- Unloading elasticity verified (parallel slopes, same E)
- Energy dissipation positive and increasing

---

### Benchmark 2: Elastic Unloading (Yield Surface Validation)
**Geometry**: Same as Benchmark 1 (small domain)  
**Material**: Steel (yield: σ_y = 250 MPa)  
**Loading Profile**:
- Load: ε = 0 to 0.8% (elastic, no yielding)
- **Check**: Verify no plastic deformation
- Unload: ε = 0.8% to 0
- **Check**: Verify stress-strain follows elastic path

**Expected Outcome**:
- No plastic strain accumulated (ε_p = 0 always)
- Stress reaches 0.8% × 200 GPa = 1600 MPa (within yield)
- No hysteresis: loading and unloading paths identical
- Demonstrates yield surface boundary (250 MPa not crossed)

**Reference Solution**:
- Linear elasticity (no plasticity): σ = E × ε
- Verification: final stress-strain point lies on elastic line

**File**: `benchmark_plasticity_elasticregion.m`

**Acceptance Criteria**:
- Zero plastic strain throughout
- Stress-strain path perfectly linear
- Identical loading/unloading paths
- No energy dissipation (elastic only)

---

### Benchmark 3: Yield Surface & J2 Flow Validation
**Geometry**: Proportional loading (composite stress states)  
**Material**: J2 plasticity (yield: σ_eq = 250 MPa, no hardening)  
**Loading**: Set up 3 different stress paths  
- Path 1: Pure tension (σ_x only)
- Path 2: Pure shear (τ_xy only)
- Path 3: Biaxial tension (σ_x = σ_y, both equal)

**Expected Outcome**:
- Path 1: Yield at σ_x = 250 MPa
- Path 2: Yield at τ_xy = 250/√3 ≈ 144 MPa (J2 criterion)
- Path 3: Yield at σ_x = σ_y = 250 MPa (von Mises: √(σ_x² + σ_y²) = 250)
- Verify J2 criterion: $\sqrt{\frac{1}{2}(σ_x - σ_y)^2 + ...} = σ_y$

**Reference Solution**:
- Von Mises yield criterion (J2 plasticity)
- Analytical yield stresses for each loading path

**File**: `benchmark_plasticity_j2criterion.m`

**Acceptance Criteria**:
- All 3 loading paths yield at correct stresses (within 1%)
- J2 criterion verified mathematically
- Stress tensor components match expected values

---

### Benchmark 4: Combined Geometric + Material Nonlinearity
**Geometry**: Cantilever beam (same as nonlinear geometric benchmark, but with plasticity)  
**Material**: Steel with small yield (σ_y = 100 MPa to trigger plasticity in large displacement)  
**Loading**: Displacement control, δ = 0 to 1.0m  

**Expected Outcome**:
- Early steps (δ < 0.3m): Geometric nonlinearity dominates
- Middle steps (δ = 0.3-0.7m): Both geometric + plastic effects
- Later steps (δ > 0.7m): Plastic effects more significant, increasing iterations
- Convergence history shows transition from geometric to plastic mechanism

**Reference Solution**:
- Compare against plastic cantilever benchmark (Phase 26 existing)
- Larger displacement case
- Combined effects quantified

**File**: `benchmark_plastic_geometric_combined.m`

**Acceptance Criteria**:
- Analysis converges to final displacement
- Plastic strain distributed in high-stress regions (root of cantilever)
- Convergence history shows expected difficulty progression
- Stress-strain history recorded and plots generated

---

### Benchmark 5: Material Model Documentation
**Deliverable**: Complete material nonlinearity formulation document  

**Contents**:

1. **J2 Plasticity Theory**:
   - Stress deviator definition
   - Von Mises yield surface: $f = \sqrt{\frac{3}{2} s : s} - \sigma_y$
   - Flow rule (normality condition)

2. **Isotropic Hardening**:
   - Yield strength evolution: $\sigma_y(p) = \sigma_y^0 + H \cdot p$
   - Hardening parameter $H$
   - Cumulative plastic strain $p$

3. **Stress Integration** (ADR-002: Trial-Commit):
   - Trial elastic step: $\sigma^{trial} = \sigma_n + D \Delta \varepsilon$
   - Check yield: $f^{trial} > 0$ ?
   - If yielding: correct via plasticity correction
   - Commit: $\sigma_{n+1} = \sigma^{corrected}$

4. **Convergence in Plasticity**:
   - Integration tolerance specifications
   - Accuracy of plastic multiplier computation
   - How nonlinearity affects Newton iterations

---

## 3. Material Implementation Validation

### Ensure Code Verifies

1. **Strain increments vs. stresses**:
   - Check that stress increases comply with tangent stiffness
   - Verify plastic flow direction (normal to yield surface)

2. **Plastic strain accumulation**:
   - Record cumulative plastic strain at each integration step
   - Plot evolution and verify increasing function

3. **Yield surface consistency**:
   - At convergence, verify |f| < tolerance
   - Check stress point lies on yield surface (for hardening cases)

4. **Unloading elasticity**:
   - When Δε_load < 0, verify elastic behavior (stiffness = E)
   - Plastic strain should remain constant during unload

---

## 4. Success Criteria (Gate 0.5 Brief-Bind)

**You confirm that you can deliver**:
- ✓ All 5 plasticity benchmarks implemented by deadline
- ✓ Material model documentation with formulations by deadline
- ✓ All hysteresis data and stress-strain curves recorded by deadline
- ✓ J2 criterion verification completed by deadline
- ✓ ADR-002 (trial-commit) compliance documented by deadline
- ✓ No blocking plasticity solver dependencies

---

## 5. BRIEF-BIND STATEMENT (Required before Gate 0.5)

```
[Your Name], acting as Plasticity Specialist, confirm full responsibility for: 
(1) cyclic loading hardening benchmark, (2) elastic unloading validation, (3) J2 
flow criterion verification, (4) combined geometric + material NL benchmark, (5) 
complete material model documentation with stress integration theory.

I confirm current availability and expected delivery: [date].
```

---

## 6. Questions for Clarification

- Should isotropic hardening be used, or include kinematic hardening as future enhancement?
- For cyclic loading, should code generate hysteresis plots, or just data arrays?
- Should yield surface validation use analytical solutions or numerical integration?
- Any specific plasticity integration scheme preference (backward Euler vs. other)?

