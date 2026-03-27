---
description: Synchronize global documents with the latest session outcomes.
---
# Workflow: sync-docs

1. **Read Sources**:
   - Read `task.md` and `walkthrough.md` from the artifacts directory.
   - Read the latest `Session_Report` in `docs/dev_logs/session_logs/`.

2. **Update Roadmap**:
   - Update `docs/PROJECT_ROADMAP.md` checkboxes (`[x]`, `[/]`).
   - Add new phases if defined in the plan.

3. **Update Refactored Plan**:
   - Update `docs/PROJECT_PLAN_REFACTORED.md` with latest statuses and dates.

4. **Update User Guide**:
   - If new features (e.g., Plasticity Viz, Arc-Length) were added, update `docs/UserGuide.md`.
