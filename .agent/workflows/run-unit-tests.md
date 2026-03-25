---
description: "Use when executing and validating unit tests after changes in FEM solver or element code."
applyTo: "tests/**"
---

# Run Unit Tests Workflow

## Steps

1. Run targeted unit tests for changed area:
   - `matlab -batch "setup_project; runtests('tests/unit');"`
2. Run integration patch tests:
   - `matlab -batch "setup_project; runtests('tests/Patchtest');"`
3. If failures occur, inspect stack trace and identify root cause in `src/`.
4. Add new test case if needed, then rerun.
5. Add log to `docs/dev_logs/` and commit.

## Verification Checklist
- [ ] All existing unit tests pass.
- [ ] New/updated tests cover the change.
- [ ] `docs/dev_logs/` phase entry created.
- [ ] commit message uses `[Phase NN]`.

