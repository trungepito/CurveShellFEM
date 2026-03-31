# Task Brief — Phase 1: Standardization & Refactoring

**Assigned to**: FEM Engineer
**Issued by**: Lead Architect
**Date**: 2026-03-28
**Status**: [ ] PENDING

---

## Objective
Standardize the `CurveShellFEM` source code for high-performance single-threaded assembly and robust nonlinear convergence.

- [ ] **Standardize Assembly**: Remove all `parfor` and replace with pre-computed triplet (`I`, `J`, `V`) indexing in `@FEM_Solver/assembleK.m` and `assembleTangentSystem.m` following `SK-04`.
- [ ] **Robust Newton Loop**: Refactor `@FEM_Solver_Nonlinear/newtonLoop.m` to use relative tolerance `‖R‖ ≤ 1e-6 · ‖F_ext‖` and the standard residual sign `R = F_int − λ·F_ext`.
- [ ] **Trial-Commit Pattern**: Implement state protection across the solver hierarchy. Solvers must return `TrialHist` and only update `HistoryData` via `commitHistory` after convergence (`SK-05`).

## Scope
- In-scope: `@FEM_Solver`, `@FEM_Solver_Nonlinear`, `@FEM_Solver_ArcLength`, `@Curve8Element`.
- Out-of-scope: Preprocessor CAD modifications, GUI updates, or parallel pool optimization.

## Required output
- **Session log**: `docs/dev_logs/sessions/2026-03-28_Phase1_Standardization_FEM_Engineer.md`
- **Report**: `docs/dev_logs/reports/FEM_Report_Phase1_Standardization.md`

## Dependencies
- Phase 0 Deep Audit (Lead Architect) is complete.

---
*Issued by Lead Architect — 2026-03-28*
