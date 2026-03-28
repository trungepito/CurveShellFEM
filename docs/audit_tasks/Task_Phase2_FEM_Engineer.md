# Task Brief — Phase 2: GMNIA Physical Validation

**Assigned to**: FEM Engineer
**Issued by**: Lead Architect
**Date**: 2026-03-28
**Status**: [ ] PENDING

---

## Objective
Validate the newly standardized J2 Plasticity integration (Trial-Commit pattern) on complex GMNIA benchmarks.

- [ ] **State Integrity**: Verify that `Material_J2Plastic` correctly computes `sig_new`, `Dep_new`, and `NewHistory` without side effects, and that these are correctly committed by the solver.
- [ ] **Convergence Consistency**: Ensure the plastic snap-through problem converges robustly with the new relative tolerance of `1e-6`.
- [ ] **Stress Recovery**: Verify that `computeTangentStiffnessAndForce` correctly returns all 20 GP plastic history points (2x2x5 layers) for each element.

## Scope
- In-scope: `@Material_J2Plastic`, `@Curve8Element_ANS_EAS`, `FEM_Solver_Nonlinear`, and `FEM_Solver_ArcLength`.
- Out-of-scope: Elastic-only solvers or linear buckling analysis.

## Required output
- **Session log**: `docs/dev_logs/sessions/2026-03-28_Phase2_GMNIA_FEM_Engineer.md`
- **Report**: `docs/dev_logs/reports/FEM_Report_Phase2_GMNIA.md` (Formal derivation record for plasticity integration required).

## Dependencies
- Phase 1 Standardized Architecture (Completed).

---
*Issued by Lead Architect — 2026-03-28*
