---
description: "Use when adding a new finite element type (Curve8Element extension) to CurveShellFEM."
applyTo: "src/**"
---

# Add New Element Type Workflow

This workflow describes the process for adding a new element type (e.g., `Curve8Element_Thermal`) with full CI verification.

## Steps

1. Identify the required changes in `src/@Curve8Element` and `src/@FEM_Solver*`.
2. Create `src/@NewElement/` inheriting from `Curve8Element`.
3. Implement `computeStiffnessMatrix`, `computeInternalForce`, and solver-specific methods.
4. Update `buildElementCache` branches in solvers (`src/@FEM_Solver_NL`, `src/@FEM_Solver_ArcLength`).
5. Add or update regression tests in `tests/unit` and `tests/Patchtest`.
6. Add/extend benchmark script in `examples/` (if needed).
7. Update documentation in `README.md` and `docs/PROJECT_FILE_REFERENCE.md`.
8. Add an entry in `docs/dev_logs/` representing Phase completion and commit reference.

## Nonlinear Solver Dev Focus
- Validate that element participates in nonlinear/Tangent updates in `@FEM_Solver_NL` and `@FEM_Solver_ArcLength`.
- Check iteration convergence, residual, and stiffness updates.

## Verification Checklist
- [ ] Reproduced baseline (existing element) behavior before change.
- [ ] New element behavior passes a dedicated unit test.
- [ ] Nonlinear convergence benchmark passes for the new element.
- [ ] `docs/dev_logs/` entry created.
- [ ] commit message uses `[Phase NN]` style.
