# Task Brief — Phase 1: Verification & Benchmarking

**Assigned to**: Verification Engineer
**Issued by**: Lead Architect
**Date**: 2026-03-28
**Status**: [ ] PENDING

---

## Objective
Verify the code refactoring for Phase 1 does not introduce regressions and maintains mathematical robustness across all benchmarks.

- [ ] **Regression Tests**: Compare stiffness matrix traces for 3 standard benchmarks (Scordelis-Lo, Pinched Cylinder, Buckling Plate) between v2.0 and the new triplet-based v3.0 logic.
- [ ] **Tolerance Validation**: Verify the relative tolerance of `1e-6` is correctly applied to the free-DOF residual norm in all nonlinear benchmarks.
- [ ] **State Integrity**: Prove the **Trial-Commit** pattern works by running a cyclic loading test and demonstrating that `HistoryData` is only updated upon convergence.

## Scope
- In-scope: All Tier 1 unit tests and Tier 3 benchmarks in `examples/`.
- Out-of-scope: Performance metrics for `parfor` (all parallel work is removed).

## Required output
- **Report**: `docs/dev_logs/reports/Verification_Report_Phase1_Standardization.md`
- **Result Logs**: In-line session log in `docs/dev_logs/sessions/2026-03-28_Phase1_Verification_Engineer.md`

## Acceptance criteria
| Benchmark | Metric | Target |
|:----------|:-------|:-------|
| Scordelis-Lo | Stiffness Trace Ratio (v3 vs v2) | 1.0 ± 1e-12 |
| Snap-through | Convergence Tolerance (rel) | ≤ 1e-6 |
| J2 Cyclic | State Consistency (Trial-Commit) | Verified |

## Dependencies
- Phase 1 Standardized Implementation (FEM Engineer) is complete (Gate 1).

---
*Issued by Lead Architect — 2026-03-28*
