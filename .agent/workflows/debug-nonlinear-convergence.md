---
description: "Use when debugging nonlinear convergence (residual, stiffness) in FEM solver paths."
applyTo: "src/**"
---

# Debug Nonlinear Convergence Workflow

## Steps

1. Reproduce convergence issue with concrete input case (e.g., `examples/snapthrough.m`, `examples/benchmark_plastic_snapthrough.m`).
2. Add verbose logging in `src/@FEM_Solver_NL`, `src/@FEM_Solver_ArcLength`:
   - residual norm
   - iteration increments
   - stiffness matrix condition
3. Trace per-element function calls in `src/@Curve8Element` (`computeTangentStiffnessAndForce`, `computeStresses`).
4. Perform parameter sweep on load step and arc-length radius.
5. Identify root cause: material model, under-integration, inconsistent kinematics, geometry update.
6. Apply fix; rerun benchmarks and tests.

## Verification Checklist
- [ ] Issue reproduced deterministically.
- [ ] Debug logs show trace to failing element or iteration.
- [ ] Fix confirmed with updated `tests/` script.
- [ ] `docs/dev_logs/` phase entry written.
- [ ] Commit message includes `[Phase NN]`.

