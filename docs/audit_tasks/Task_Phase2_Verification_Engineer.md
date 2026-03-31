# Task Brief — Phase 2: GMNIA Verification

**Assigned to**: Verification Engineer
**Issued by**: Lead Architect
**Date**: 2026-03-28
**Status**: [ ] PENDING

---

## Objective
Verify the mathematical accuracy and robustness of the standardized library across complex GMNIA benchmarks.

- [ ] **GMNIA Benchmark**: Run `examples/benchmark_plastic_snapthrough.m` and record the full equilibrium path. 
- [ ] **Path Traversal**: Confirm the **Arc-Length solver** correctly handles the snap-through point using the new standardized residual sign and relative tolerance.
- [ ] **Yield Front Visualization**: Produce a plot of the yield front (fraction of 5 Simpson layers yielded per element) at the peak load step using `plotPlasticYield` (SK-10).

## Scope
- In-scope: Nonlinear benchmarks with plasticity and large displacements.
- Out-of-scope: Linear buckling (Phase 3).

## Required output
- **Report**: `docs/dev_logs/reports/Verification_Report_Phase2_GMNIA.md`

## Acceptance criteria
| Benchmark | Metric | Target |
|:----------|:-------|:-------|
| Plastic Snap-through | Limit Load λ_crit | 0.82 ± 0.05 |
| J2 State | Plastic Fraction p > 0 | Confirmed in high-stress zones |
| Viz | Yield Plot | High-resolution; clear gradient |

## Dependencies
- Phase 1 Standardized Implementation (Completed).

---
*Issued by Lead Architect — 2026-03-28*
