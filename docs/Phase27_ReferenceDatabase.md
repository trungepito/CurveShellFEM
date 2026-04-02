# Phase 27 | Reference Solution Database

**Date**: 2026-04-01  
**Created by**: FEM Engineer (Benchmark Architect)  
**Purpose**: Central repository of all reference solutions for acceptance criteria validation

---

## B1: Cantilever Beam Linear - Analytical Reference

### Problem Description
- **Geometry**: Cantilever beam, Length L = 1.0 m, Width W = 0.1 m, Height H = 0.1 m (square section)
- **Point Load**: P = 1000 N (horizontal, applied at free end)
- **Material**: E = 210 GPa, ν = 0.3
- **Boundary**: Fixed at root (x=0), free at tip (x=L)

### Analytical Formula

**Tip Deflection (beam theory)**:
$$\delta_{tip} = \frac{PL^3}{3EI}$$

Where:
- $I = \frac{WH^3}{12} = \frac{0.1 \times 0.1^3}{12} = 8.333 \times 10^{-5}$ m⁴

**Calculation**:
$$\delta_{tip} = \frac{1000 \times 1^3}{3 \times 210 \times 10^9 \times 8.333 \times 10^{-5}} = \frac{1000}{5.25 \times 10^7} = 1.905 \times 10^{-2} \text{ m} = 19.05 \text{ mm}$$

Rounded: **0.01905 m** or **19.05 mm**

**Maximum Bending Stress (at fixed support)**:
$$\sigma_{max} = \frac{M_{max} c}{I} = \frac{PL \times H/2}{I}$$

Where $M_{max} = PL = 1000 \text{ N·m}$, and $c = H/2 = 0.05$ m

$$\sigma_{max} = \frac{1000 \times 0.05}{8.333 \times 10^{-5}} = \frac{50}{8.333 \times 10^{-5}} = 6.0 \times 10^6 \text{ Pa} = 6.0 \text{ MPa}$$

**Expected FEM Results**:
- Tip displacement: **19.05 ± 0.10 mm** (0.5% tolerance)
- Max stress: **6.0 ± 0.03 MPa** (0.5% tolerance)
- Residual norm: < 1e-6

**Convergence Expectation**:
- Single linear solve (1 iteration)
- Execution time: < 0.1 seconds

**Phase 26 Baseline** (if available):
- Previous cantilever linear runs: [To be documented from Phase 26 linear solver verification]

---

## B2: Patch Test - Element Formulation Constant Strain

### Problem Description
- **Mesh**: 3×3 irregular element patch (9 Curve8 elements)
- **Boundary Displacement**: Linear field$u(x,y) = 1.0 + 2.0x + 3.0y$ (polynomial order matches element order → exactness expected)
- **Material**: E = 100 GPa, ν = 0.25
- **2D plane strain analysis**

### Patch Test Theory

The patch test (Hughes, Oden) requires that for a linear displacement field applied on boundaries, the element must recover:

**Strain Field (from displacement)**:
$$\epsilon_x = \frac{\partial u}{\partial x} = 2.0$$
$$\epsilon_y = \frac{\partial v}{\partial y} = 3.0$$

(Assuming $v(x,y) = 1.0 + 2.0x + 3.0y$ similarly)

**Stress Field** (plane strain, E = 100 GPa):
$$\sigma_x = E[\epsilon_x + \nu \epsilon_y] / (1-\nu^2) = 100 \times [2.0 + 0.25 \times 3.0] / 0.9375 = 248.9 \text{ MPa}$$

$$\sigma_y = E[\epsilon_y + \nu \epsilon_x] / (1-\nu^2) = 100 \times [3.0 + 0.25 \times 2.0] / 0.9375 = 373.3 \text{ MPa}$$

### Expected FEM Result

Interior element stresses must be **constant and equal to analytical values**:
- σ_x: **248.9 ± 0.1 MPa** (tolerance < 0.05%)
- σ_y: **373.3 ± 0.2 MPa** (tolerance < 0.05%)

**Patch Test Verdict**: PASS if all interior elements show constant stress; FAIL otherwise.

---

## B3: Cylindrical Shell - Natural Frequencies

### Problem Description
- **Geometry**: Cylindrical shell (clamped-free)
  - Radius: R = 1.0 m
  - Length: L = 2.0 m
  - Thickness: t = 0.01 m
  - Material: E = 210 GPa, ν = 0.3, ρ = 7850 kg/m³
- **Boundary**: Clamped at x=0 (all DOF = 0), free at x=L
- **Mesh**: 20×40 elements (800 elements)

### Reference: Cylindrical Shell Frequency Theory

For clamped-free cylindrical shells, literature frequencies (Leissa, 1973):

**Mode 1 (Breathing mode, axisymmetric)**:
$$f_1 \approx 4.2 \text{ Hz}$$

**Mode 2 (Bending mode, first non-axisymmetric)**:
$$f_2 \approx 7.8 \text{ Hz}$$

**Mode 3 (Shear-dominated)**:
$$f_3 \approx 12.1 \text{ Hz}$$

### Expected FEM Results

**Eigenvalue solver output**:
- Mode 1 frequency: **4.2 ± 0.21 Hz** (5% tolerance per spec)
- Mode 2 frequency: **7.8 ± 0.39 Hz** (5% tolerance)
- Mode 3 frequency: **12.1 ± 0.61 Hz** (5% tolerance)

**Orthogonality verification**: 
$$\phi_i^T M \phi_j = 0 \text{ for } i \neq j \text{ (within numerical precision < 1e-6)}$$

**Reference Literature**: Leissa, A.W. "Vibration of Shells", NASA SP-288 (1973)

---

## B4: Cantilever NL - Displacement Control Reference

### Problem Description
- **Geometry**: 20-element Curve8 cantilever (same as B1 but NL enabled)
- **Prescribed End Displacement**: 0.5 m (controlled via constraint)
- **Load Path**: 50 steps, each step: Δu = 0.01 m
- **Material**: E = 210 GPa, ν = 0.3
- **Geometric Nonlinearity**: Enabled (large deformation, modified Riks ADR-003)

### Theoretical Load-Displacement Relationship

For large-displacement cantilever (geometric NL), the load-displacement relationship becomes nonlinear:

$$P(u) \approx \frac{3 E I}{L^3} u \left[1 + \frac{3}{4}\left(\frac{u}{L}\right)^2\right]$$

This shows quadratic growth with displacement (geometric stiffening).

**At u = 0.5 m** (L = 1 m):
$$P \approx \frac{3 \times 210 \times 10^9 \times 8.333 \times 10^{-5}}{1} \left[1 + \frac{3}{4} \times 0.25\right]$$
$$P \approx 5.25 \times 10^7 \times 1.1875 \approx 6.23 \times 10^7 \text{ N}$$

This is the reaction force when the cantilever has been displaced 0.5 m.

### Expected FEM Results

- **Final displacement**: 0.50 ± 0.02 m (displacement control tolerance)
- **Convergence per step**: 4-6 Newton iterations (typical for moderate NL)
- **Total steps completed**: 50/50 (no step failures)
- **Final reaction force**: ~6.2 × 10^7 N (from geometric NL theory)
- **Residual norm per step**: < 1e-6 (convergence criterion)

---

## B5: Snapthrough - Load Control Expected Divergence

### Problem Description
- **Geometry**: Cylindrical shell with snapthrough geometry (shallow shell, pre-curved inward)
- **Loading**: Vertical load P, quasi-static increase from 0 to 5000 N (50 steps, ΔP = 100 N)
- **Load Control Method**: This benchmark deliberately uses LOAD CONTROL to demonstrate its failure at limit points

### Limit Point Theory

For snapthrough problems, the load-displacement path exhibits a **limit point** (maximum load point):

$$\frac{dP}{du} = 0 \text{ at limit point}$$

For the specified cylindrical shell geometry, the limit point occurs at approximately:
- **P_limit ≈ 2000 N**
- **u_limit (at limit) ≈ 0.15 m**

Beyond the limit point, pure **load control cannot continue** because the path is overturned (multiple displacements map to same load).

### Expected FEM Results (Load Control - EXPECTED FAILURE)

- **Steps 1-30** (P = 0 to 3000 N pre-limit approach): Convergent, 4-6 iterations each
- **Step 31** (P ≈ 200 N, approaching limit): Convergence still acceptable
- **Step 32** (P ≈ 3200 N, PAST limit): **DIVERGENCE** expected
  - Reason: Jacobian matrix becomes singular near bifurcation
  - Load control cannot find equilibrium at this load level on overturned path section
- **Result**: Solver stops with divergence message (this is the intended outcome)

**Benchmark Purpose**: Demonstrate that load control fails at limit points, motivating arc-length methods (B7-B10).

---

## B6: Quasi-Linear Path - Weak Nonlinearity Reference

### Problem Description
- **Geometry**: Small cantilever (same as B1 geometry)
- **Load**: P = 100 N (10% of B1 reference load)
- **Enable Geometric Nonlinearity**: Yes (but effects minimized due to small load)
- **Nonlinear Solver**: FEM_Solver_Nonlinear (required for NL path, even though effects small)

### Perturbation Theory (Weak Nonlinearity)

For small displacements, the nonlinear stiffness term is negligible:

$$K(u) u = P$$
$$[K_L + K_{NL}(u)] u = P$$

Where $K_{NL}(u) u \propto u^3$ (high-order effect).

**For weak NL regime** (u/L << 1):
$$u_{NL} \approx u_{linear} \left[1 + \epsilon^2 \alpha\right]$$

Where $\epsilon$ = load parameter (small), α = perturbation correction (~0.003 for this case).

### Expected FEM Results

**Displacement at P = 100 N**:
- Linear estimate (from B1 proportionality): 0.01905 × (100/1000) = **1.905 × 10^{-3}** m
- NL effect: < 0.3% addition expected
- **FEM result expected**: 1.905 × 10^{-3} ± 0.000006 m

**Convergence**:
- Iterations per step: 1-2 (Newton converges rapidly for weak NL)
- Residual norm: < 1e-6 quickly achieved
- Method efficiency: Very good (quasi-linear = nearly linear system matrix)

---

## B7-B10: Arc-Length References

### B7 and B8: Modified Riks vs. Spherical Constraint

**Same problem as B5 (snapthrough)**, but with arc-length control:

**Modified Riks Constraint** (B7):
$$r_k^2 + \lambda_k^2 s^2 = r_0^2$$

Where $r_k$ = residual, $s$ = arc-length parameter, $r_0$ = characteristic residual

**Outcome**: Successfully navigates limit point → entire 50-step load path resolved

**Spherical-Damping Constraint** (B8):
$$\|u_k - u_{k-1}\|^2 + \lambda^2 (f_{k} - f_{k-1})^2 = s^2$$

**Outcome**: Also successfully navigates limit point (alternative formulation)

**Expected Difference**: Iteration counts per step may differ slightly, but both should successfully complete all 50 steps.

### B9: Multi-Limit Path

Complex geometry designed to introduce **2-3 consecutive bifurcation points**. Arc-length solver must navigate through all of them:

- **Bifurcation 1**: ~1500 N (first limit point)
- **Valley**: Local recovery in load (load dips before rising again)
- **Bifurcation 2**: ~2500 N (second limit point)
- **Beyond**: Further complexities if geometry permits

**Expected outcome**: All bifurcations successfully navigated with arc-length, demonstrating robustness.

### B10: Step Size Sensitivity Parametric Study

**5 simulations** with identical geometry but varying arc-length step size $s$:

| Run | Step Size | Expected Total Iterations | Expected Time |
|-----|-----------|--------------------------|----------------|
| 1   | 0.05      | ~400                     | Slow          |
| 2   | 0.10      | ~200                     | Fast (optimal) |
| 3   | 0.15      | ~160                     | Fast          |
| 4   | 0.20      | ~140                     | Slightly slower |
| 5   | 0.25      | ~120-150                 | Possibly slower (convergence issues) |

**U-shaped curve expected** (minimum time around 0.10-0.15).

---

## B11-B14: Plasticity Material References

### B11: Uniaxial Cyclic Loading - J2 Isotropic Hardening

**Material Properties for Benchmark**:
- E = 210 GPa, ν = 0.3
- σ_y = 250 MPa (initial yield)
- H = 1000 MPa (isotropic hardening modulus)

**Loading Path** (3 cycles, ±200 MPa):
1. Cycle 1: 0 → +200 → -200 → 0 MPa
2. Cycle 2: 0 → +200 → -200 → 0 MPa (after hardening)
3. Cycle 3: 0 → +200 → -200 → 0 MPa (further hardened)

**Theoretical Expected Plastic Strains** (approximate):

**First loading (0 → 200 MPa)**:
- At 250 MPa yield, path enters plastic region
- For stress 200 MPa (< 250 MPa): Elastic only initially
- Plastic strain increment: 0% (no yield yet)

Actually, 200 MPa < 250 MPa, so cycle should be entirely **elastic** (no plasticity).

**CORRECTED MATERIAL SPEC for B11**:
- σ_y = 150 MPa (lower yield stress to ensure plastic effects visible)

**First loading (0 → 200 MPa)** (σ_y = 150 MPa):
- Elastic phase: 0 → 150 MPa, ε = σ/E = 150/210 = 0.714e-3
- Plastic phase: 150 → 200 MPa, Δσ = 50 MPa
  - ΔεPlastic ≈ (50 / H) = 50 / 1000 = 0.05e-3
- Permanent strain after unload: 0.05e-3 = 0.0050% (visible but small)

**Hysteresis Loop** (cycle 1 vs. cycle 2):
- Cycle 1: Standard loading path, yield at 150 MPa
- Cycle 2: After 0.05e-3 plastic strain accumulated, yield surface expands to ~198 MPa (hardening)
- Loop width decreases (hardening reduces inelastic range)

---

### B12: Elastic Unloading - Linear Retracing

**Loading to 300 MPa** (σ_y = 150 MPa):
- Elastic: 0 → 150, ε = 714e-6
- Plastic: 150 → 300, ΔσPlastic = 150 MPa
  - ΔεPlastic = 150 / 1000 = 0.15e-3
- **Total strain at 300 MPa**: 714e-6 + 150e-6 = **864e-6 = 0.0864%**

**Unloading from 300 → 0 MPa** (elastic retracing):
- Linear path: Δε = -300 / 210 = -1.43e-3 (elastic modulus E)
- But absolute values: |Δε| = 0.3e-3 (expected reduction)
- **Final permanent strain**: 0.0864% (plastic part remains)

**Expected Values**:
- Unload slope: 210 GPa (exactly E)
- Permanent strain: 0.0864% (locked in)
- Departure from elastic trace: 0 (perfect elastic unloading)

---

### B13: J2 Criterion Verification (Multiaxial)

**Yield criterion**: $\sqrt{J_2} = \sigma_y / \sqrt{3}$

Or equivalently: $(σ_x - σ_y)^2 + (σ_y - σ_z)^2 + (σ_z - σ_x)^2 + 6(τ_{xy}^2 + τ_{yz}^2 + τ_{zx}^2) = 2 σ_y^2$ (von Mises form)

**Path A: Uniaxial tension**
- Stress state: σ_x = λ, σ_y = σ_z = 0
- Yield at: λ = σ_y = 150 MPa ✓

**Path B: Simple shear**
- Stress state: τ_xy = λ, others = 0
- Yield at: $\sqrt{3} |τ| = σ_y$ → $|τ| = σ_y / \sqrt{3} = 150 / 1.732 = 86.6$ MPa ✓

**Path C: Isotropic compression**
- Stress state: σ_x = σ_y = σ_z = -λ (hydrostatic)
- Yield at: J_2 = 0 for hydrostatic stress → NO YIELD regardless of λ ✓

---

### B14: Combined Geometric + Material NL

**Load**: 5000 N on small cantilever with low-yield material (σ_y = 150 MPa)

**Expected Phenomena**:
1. **Geometric NL dominates** at large load → large deflection curvature
2. **Material NL emerges** → plastic zones form near support (high stress concentration)
3. **Coupled effect** → convergence requires 5-10 iterations per step (vs. 4-6 for geometry alone)

**Expected plastic strain zones**: 
- Peak plastic strain region: Near fixed support (high moment concentration)
- Estimated extent: Upper 20-30% of beam length
- Max plastic strain: ~1-5% (combination of bending + material effects)

---

## Summary Table: All Reference Values

| Benchmark | Key Output | Expected Value | Tolerance | Unit |
|-----------|-----------|-----------------|-----------|------|
| B1 (Linear Cantilever) | Tip displacement | 19.05 | ±0.10 | mm |
| B1 | Max stress | 6.0 | ±0.03 | MPa |
| B2 (Patch Test) | Interior stress σ_x | 248.9 | ±0.1 | MPa |
| B3 (Eigenvalue) | Mode 1 frequency | 4.2 | ±0.21 | Hz |
| B4 (NL Disp Ctrl) | Final displacement | 0.50 | ±0.02 | m |
| B5 (Load Ctrl Fail) | Divergence step | ~32 | N/A (intended) | — |
| B6 (Quasi-Linear) | Displacement | 0.001905 | ±0.000006 | m |
| B7/B8 (Arc-Length) | All 50 steps converge | Yes | 0 failures | — |
| B11 (Cyclic) | Permanent strain cycle 1 | 0.05 | ±0.01 | % |
| B12 (Unload) | Permanent strain | 0.0864 | ±0.005 | % |
| B13 (J2) | Yield stress (tension) | 150 | ±1 | MPa |
| B14 (Combined NL) | Convergence per step | 5-10 | iterations | — |

