---
description: "Use when extending J2 plasticity material model or adding a new material model in FEM module."
applyTo: "src/**"
---

# Material Model Extension Workflow

## Steps

1. Review current material model implementation in `src/@Material_J2Plastic`.
2. Add new model class/module (e.g., `@Material_J2Plastic_Extended` or `@Material_Custom`).
3. Add integration points in solver material update path.
4. Add unit/regression tests in `tests/unit` and benchmark in `examples/`.
5. Update documentation and phase logs.

## Verification Checklist
- [ ] material model updates pass unit tests.
- [ ] existing plasticity benchmarks still pass.
- [ ] `docs/dev_logs/` entry created.
- [ ] commit message uses `[Phase NN]`.
