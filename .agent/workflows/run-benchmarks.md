---
description: "Use when running benchmark scripts to verify performance and correctness for nonlinear solver changes."
applyTo: "examples/**"
---

# Run Benchmarks Workflow

## Steps

1. Run benchmark scripts for solver/element validation:
   - `matlab -batch "setup_project; run('examples/benchmark_plastic_cantilever.m');"`
   - `matlab -batch "setup_project; run('examples/benchmark_plastic_snapthrough.m');"`
2. Compare outputs with baseline (load-displacement, energy, convergence).
3. Report timing and performance metrics.
4. If regression found, execute solver debug workflow.
5. Add `docs/dev_logs/` entry and commit.

## Verification Checklist
- [ ] Benchmarks run successfully.
- [ ] Results within expected tolerance.
- [ ] Performance baseline maintained.
- [ ] `docs/dev_logs/` entry updated.
- [ ] commit message includes `[Phase NN]`.

