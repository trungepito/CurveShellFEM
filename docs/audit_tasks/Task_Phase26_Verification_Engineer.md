# Task Brief — Phase 26: FEM_Solver_Nonlinear Defect Verification

**Phase**: 26
**Status**: GATE 0 — ISSUED
**Date**: 2026-03-31
**Issued by**: Lead Architect
**Authority**: v4.1 Agent System, Escalated Defect Response

---

## Objective

**As Verification Engineer, your responsibility is to:**

1. Confirm that FEM Engineer's defect fix resolves the solver unit test failures
2. Verify that no regression occurs in existing benchmarks
3. Validate convergence behavior matches mathematical specification in ADR-003 (arc-length) and ADR-002 (history management)
4. Issue verification report confirming fix is production-ready

**Acceptance**: All unit tests pass; all existing benchmarks still pass (within tolerance).

---

## Scope (In-Scope)

- Unit test execution: `tests/unit/TestSolvers.m` (must pass 100%)
- Regression testing on existing benchmarks:
  - `benchmark_snapthrough_arclength.m` (snap-back detection, convergence)
  - `benchmark_gmnia_cylindrical_panel.m` (nonlinear buckling)
  - `benchmark_plastic_cantilever.m` (plasticity + convergence)
- Phase 25 verification of trial-commit pattern (ADR-002 compliance)
- Verification report detailing test results and any regressions

---

## Scope (Out-of-Scope)

- Benchmark development (only execution of existing benchmarks)
- Code changes (FEM Engineer responsibility)
- Physics derivation (FEM Engineer responsibility)

---

## Acceptance Criteria — Gate 1 Verification

**All of the following must be true before Gate 2:**

- [x] `tests/unit/TestSolvers.m` passes with 0 failures (4/4 tests pass)
- [ ] Benchmark 1 (`benchmark_snapthrough_arclength.m`) passes and converges within 2% tolerance
- [ ] Benchmark 2 (`benchmark_gmnia_cylindrical_panel.m`) passes and matches reference load-displacement curve
- [ ] Benchmark 3 (`benchmark_plastic_cantilever.m`) passes and history variables persist correctly
- [ ] FEM Engineer session log exists and documents root cause + fix
- [ ] Verification report issued confirming zero regressions
- [ ] Lead Architect confirms fixes do not violate ADR-001 through ADR-005 constraints

---

## Test Execution Plan

### Unit Tests

```matlab
% Run in MATLAB
cd 'path/to/CurveShellFEM'
results = runtests('tests/unit/TestSolvers.m', 'Verbosity', 2)
```

**Pass criteria**: `results.Passed == 4 && results.Failed == 0`

### Benchmark Tests

```matlab
% Run each individually and plot results
benchmark_snapthrough_arclength()          % Check convergence
benchmark_gmnia_cylindrical_panel()        % Check load curve
benchmark_plastic_cantilever.m()           % Check plasticity tracking
```

**Pass criteria**: No MATLAB errors; output plots visually reasonable (no NaN, Inf, or non-monotonic solutions where expected)

---

## Verification Report Checklist

File: `docs/dev_logs/reports/Verification_Report_Phase26_NLSolver.md`

- [ ] Unit test summary (4/4 passed)
- [ ] Benchmark regression table (3 benchmarks checked; all pass/fail status)
- [ ] Trial-commit pattern verification (TrialHist properly committed on convergence)
- [ ] Convergence tolerance verification (compatible with ADR-002 spec)
- [ ] Stale-doc check on FEM Engineer session log (mandatory fields present)
- [ ] Verdict: **PASS** (if all above green)

---

## Constraints & Notes

- **Tolerance**: Benchmarks must match reference within ±2% (if reference exists) or visual inspection passes
- **Timeline**: Target completion 2026-04-15
- **If failures occur**: Follow AGENT_CHARTER.md §3.3 (FEM Engineer ↔ VE loop; Lead Architect mediates after 2 cycles)

---

*Issued by: Lead Architect — v4.1 CurveShellFEM*
*Effective immediately upon user confirmation*

---

**NEXT STEP**: Await FEM Engineer fix; then execute verification protocol above.
