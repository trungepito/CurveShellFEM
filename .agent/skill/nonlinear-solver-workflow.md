---
name: curve-shell-fem-nonlinear-solver
description: "Skill for nonlinear solver development workflows in CurveShellFEM."
---

# CurveShellFEM Nonlinear Solver Development Skill

Use this skill when you are extending or debugging nonlinear solver behavior, including arc-length solver and J2 plasticity interactions.

## Key workflows
- `/add-element-type` → add and integrate a new element formulation
- `/debug-nonlinear-convergence` → root cause analysis for convergence failure
- `/run-unit-tests` → execute tests and confirm fix
- `/run-benchmarks` → run performance and nonlinear benchmarks

## Rules
1. Always start with reproducible baseline case.
2. Log all changes in `docs/dev_logs/` with phase metadata.
3. Give priority to `src/@FEM_Solver_NL` and `src/@FEM_Solver_ArcLength` paths.
4. Ensure test coverage via `tests/unit` and `tests/Patchtest`.
## Sample
1. Always look into the samples in `.agent/skill/samples/`to get the embbed logics first