# Phase 27 | Task Brief: Benchmark Architect (FEM Engineer Lead)
**Date**: 2026-03-31  
**Phase**: 27 (Comprehensive Benchmark Suite)  
**Role**: Benchmark Architect (FEM Engineer Leading Methodology)  
**Gate**: 0 → 0.5 (Awaiting Brief-Bind)

---

## 1. Objective (VERBATIM FROM PHASE 27 ASSEMBLY)

"The current benchmark suite covers only 3-4 use cases. We need a comprehensive benchmark suite that systematically validates all solver types (Linear, Nonlinear, Adaptive, Arc-Length) and physics modes (geometry, buckling, nonlinear, plasticity). Your responsibility as Benchmark Architect is to: (1) Design the complete benchmark matrix covering all solver × physics combinations, (2) Define selection criteria for geometries and loading cases, (3) Establish acceptance criteria and error tolerances, (4) Create/enhance benchmarks for linear solver and eigenvalue analysis, (5) Document analytical reference solutions or literature justification, (6) Ensure all 19 benchmarks are properly structured and executable."

---

## 2. Scope: Linear & Eigenvalue Benchmarks

### Your Deliverables

**Benchmark 1: Cantilever Beam (Linear, Analytical Compare)**
- **Geometry**: 10m cantilever, I-beam cross-section (1.0×0.1m)
- **Material**: Steel (E=200 GPa, ν=0.3)
- **Loading**: Point load at tip (1000 N downward)
- **Expected Outcome**: 
  - Tip deflection: Compare FEM vs. analytical formula $\Delta = \frac{PL^3}{3EI}$
  - Error tolerance: < 0.1% (element formulation validation)
- **Reference Solution**: Classical beam theory
- **File**: `benchmark_cantilever_linear.m`
- **Documentation**: Include analytical derivation

**Benchmark 2: Patch Test (Element Formulation)**
- **Geometry**: Single or few 8-node shell elements under:
  - Constant strain state
  - Linear displacement field
- **Loading**: Boundary tractions giving pure shear or tension
- **Expected Outcome**: 
  - Element reproduces exact displacement & stress
  - Error: < machine precision (element formulation validation)
- **Reference Solution**: Patch test theory (Irons & Razzaque, 1972)
- **File**: `benchmark_patch_test.m`
- **Documentation**: Element ansatz space analysis

**Benchmark 3: Buckling Plate (Eigenvalue Analysis)**
- **Existing**: `benchmark_buckling_plate.m` (review, may enhance)
- **Validation**: 
  - Compare first 3 eigenvalues to analytical solution (rectangular plate)
  - Critical buckling load: $P_{crit} = \frac{\pi^2 EI}{L^2}$ (for pinned-pinned)
- **Enhancement**: Add convergence study (mesh refinement → eigenvalue convergence)
- **File**: Enhanced version of existing
- **Documentation**: Analytical reference for plate buckling

**Benchmark 4: Cylindrical Shell Vibration (Eigenvalue - Geometry Check)**
- **Geometry**: Cylindrical shell (radius R, height H)
- **Material**: Isotropic (E, ν)
- **Method**: Free vibration eigenvalue analysis (no load)
- **Expected Outcome**: 
  - Natural frequencies match literature
  - Mode shapes sensible (sinusoidal around circumference)
- **Reference Solution**: Classical shell theory (Timoshenko & Woinowsky-Krieger)
- **File**: `benchmark_cylindrical_shell_vibration.m`
- **Documentation**: Shell eigenvalue formulation

---

## 3. Benchmark Design Responsibilities

### Comprehensive Matrix Definition

Create a detailed **Benchmark Matrix** documenting:

**Matrix Structure**:
```
|             | Linear | Nonlinear-DispCtrl | Nonlinear-LoadCtrl | Arc-Length | Adaptive |
|-------------|--------|-------------------|-------------------|-----------|----------|
| Geometry    | ...    | ...               | ...               | ...       | ...      |
| Plasticity  | ...    | ...               | ...               | ...       | ...      |
| Buckling    | ...    | ...               | ...               | ...       | ...      |
```

**For Each Cell**:
1. Benchmark name
2. Geometry type
3. Loading type
4. Expected solver behavior
5. Acceptance criteria
6. Reference solution
7. Priority (HIGH/MEDIUM/LOW)

---

## 4. Acceptance Criteria Framework

### Define Tolerance Matrices

**Table 1: Displacement Error Tolerance**
```
Problem Class | Tolerance | Justification
Linear        | 0.1%      | Element accuracy (8-node shell)
Nonlinear (L) | 1.0%      | Linearization + Newton iterations
Nonlinear (NL)| 2.0%      | Geometric nonlinearity accumulation
Arc-Length    | 1.5%      | Path following + constraint handling
Plasticity    | 2.5%      | Hardening algorithm + stress integration
```

**Table 2: Convergence Metrics**
```
Solver      | Max Iterations | Relative Residual | Absolute Tolerance
Linear      | N/A            | 1e-10 (direct)    | 1e-12
Nonlinear   | 20             | 1e-6              | 1e-8
Arc-Length  | 15             | 1e-6              | 1e-8
Adaptive    | variable       | 1e-6              | 1e-8
```

**Table 3: Performance Benchmarks**
```
Problem Size | Linear Solve Time | Nonlinear Iterations | Arc-Length Steps
Small (<100 DOFs)      | < 0.01 s      | 3-5                 | 30-50
Medium (500-1k DOFs)   | 0.05-0.1 s    | 4-8                 | 40-60
Large (2k+ DOFs)       | > 0.1 s       | 5-10                | 50-100
```

---

## 5. Reference Solution Strategy

### For Each Benchmark, Establish:

1. **Analytical Reference** (where available)
   - Beam theory formulas
   - Plate theory eigenvalues
   - Closed-form solutions
   - Classical mechanics derivations

2. **Literature Reference** (peer-reviewed sources)
   - Benchmark problem descriptions
   - Published FEM results
   - Experimental validation
   - Citations (author, year, page)

3. **Numerical Baseline** (Phase 26 results used as baseline)
   - Run benchmarks with Phase 26 solver
   - Record convergence history
   - Store displacement/stress fields
   - Use as regression check in future phases

**Documentation**: For each benchmark, include a `Reference_` section with:
- Source (analytical, literature, or Phase 26 baseline)
- Justification (why this reference is valid)
- Expected values (tabulated)
- Error bounds (±% tolerance)

---

## 6. Deliverables Checklist

### Benchmark Architecture
- [ ] Complete benchmark matrix (all 19 benchmarks mapped)
- [ ] Solver × Physics coverage: 100% specification
- [ ] Acceptance criteria document (tolerance tables)
- [ ] Reference solution strategy document
- [ ] Analytical derivations where applicable

### Linear Solver Benchmarks
- [ ] `benchmark_cantilever_linear.m` — Analytical compare
- [ ] `benchmark_patch_test.m` — Element formulation
- [ ] `benchmark_buckling_plate.m` — Enhanced with convergence study
- [ ] `benchmark_cylindrical_shell_vibration.m` — Eigenvalue validation

### Documentation
- [ ] Benchmark selection criteria (why each problem)
- [ ] Analytical reference justifications
- [ ] Expected outcome descriptions
- [ ] Usage guide for each benchmark
- [ ] Performance baseline summary

---

## 7. Success Criteria (Gate 0.5 Brief-Bind)

**You confirm that you can deliver**:
- ✓ All 4 linear/eigenvalue benchmarks implemented by deadline
- ✓ Complete benchmark matrix and acceptance criteria document by deadline
- ✓ Analytical derivations or literature references for all benchmarks by deadline
- ✓ No blocking dependencies (all required solvers available)
- ✓ Clear interface with other FEM Engineers (for nonlinear/plasticity benchmarks)

---

## 8. BRIEF-BIND STATEMENT (Required before Gate 0.5)

Please respond with a brief statement confirming:

**Example Template**:
```
[Your Name], acting as Benchmark Architect, confirm that I have reviewed the 
objective and understand full responsibility for: (1) designing the comprehensive 
benchmark matrix, (2) defining acceptance criteria framework, (3) establishing 
reference solution strategy, (4) implementing linear and eigenvalue benchmarks, 
(5) documenting all mathematical foundations.

I confirm current availability and no blocking constraints. Expected delivery: 
[date, e.g., 2026-04-XX].
```

---

## 9. Questions & Clarifications

**Blockers to Address**:
- Do we need experimental validation for any benchmarks, or is literature sufficient?
- Should analytical derivations be in-code comments or separate documentation?
- For eigenvalue problems, how many modes should be computed/stored?
- Are there any missing benchmark types you'd recommend adding?

---

## Phase 27 Leadership Coordination

**Lead Architect** will:
- [ ] Collect brief-bind statements from all 7 team members
- [ ] Resolve any blockers or dependencies
- [ ] Authorize Gate 0.5 transition
- [ ] Coordinate between benchmark architect and other FEM Engineers

**Expected Timeline**:
- Brief-bind collection: 1-2 hours
- Implementation: 30-40 hours total (distributed across 5 FEM Engineers)
- VE automation: 8-10 hours
- Documentation: 4-6 hours
- **Total Phase 27 Duration**: ~1 week

