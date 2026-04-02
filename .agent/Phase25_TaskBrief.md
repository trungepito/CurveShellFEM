# Task Brief — Phase 25: Governance Cleanup (Legacy Debt Clearing)

**Assigned to**: Lead Architect + Project Scribe (governance); FEM Engineer (ADR backfill)
**Issued by**: Lead Architect
**Date issued**: [YYYY-MM-DD — fill when issued]
**Status**: PENDING
**Formal FEM report required**: NO — no src/ changes in this phase
**Gate 0.5 required**: NO — no src/ changes; brief-bind still required for FEM Engineer ADR work

---

## Gate precondition
This brief constitutes Gate 0 for Phase 25.
Phase 25 has no `src/` implementation work. All tasks are governance and documentation.

---

## Context
Audit of Phases 9–24 found:
- Phase 21 opened and never closed (Status: "In Progress", Log: "TBD")
- Phases 22, 23, 24 executed with no task briefs, no Gate 0, no Gate 0.5
- PROJECT_ROADMAP.md shows Phase 10 as PROPOSED despite completion report existing
- dev_logs/index.md has no entry for Phase 22
- Multiple reports contain `file:///` absolute paths (machine-local)
- Five core architectural decisions exist only in Skill Library, not as ADRs

---

## Objective

- [ ] Resolve PROJECT_ROADMAP.md / index.md drift for Phases 9–12 (retroactive WF-06)
- [ ] Formally close Phase 21 as ABANDONED with rationale
- [ ] Generate retroactive task briefs for Phases 22, 23, 24
- [ ] Backfill five core ADRs (see below)
- [ ] Execute full retroactive index.md and roadmap alignment
- [ ] Fix or flag all `file:///` absolute paths across existing reports

---

## Scope

**In scope**:
- `docs/` directory only — `dev_logs/`, `audit_tasks/`, `adr/`, `PROJECT_ROADMAP.md`, `PROJECT_PLAN_REFACTORED.md`
- `PHASE_STATE.md` history block
- `docs/adr/INDEX.md` creation

**Out of scope**: Any `src/` or `tests/` modification.

---

## Deliverables

### Project Scribe deliverables
1. Updated `docs/dev_logs/index.md` — entries for all phases 9–24
2. Updated `docs/PROJECT_ROADMAP.md` — correct checkbox states for all phases
3. Updated `docs/PROJECT_PLAN_REFACTORED.md` — status and dates for all phases
4. `PHASE_STATE.md` retroactive history block (see format below)
5. Phase 21 ABANDONED entry in index.md and roadmap

### Lead Architect deliverables
6. `docs/audit_tasks/Task_Phase22_FEM_Engineer_RETROACTIVE.md`
7. `docs/audit_tasks/Task_Phase23_FEM_Engineer_RETROACTIVE.md`
8. `docs/audit_tasks/Task_Phase24_FEM_Engineer_RETROACTIVE.md`

### FEM Engineer deliverables (ADR backfill)
9. `docs/adr/ADR-001-Triplet-Sparse-Assembly.md` — Proposed (Architect accepts)
10. `docs/adr/ADR-002-Trial-Commit-History-Pattern.md` — Proposed
11. `docs/adr/ADR-003-Modified-Riks-Hyperplane-Constraint.md` — Proposed
12. `docs/adr/ADR-004-Integration-Scheme-2x2x5.md` — Proposed
13. `docs/adr/ADR-005-Double-Arithmetic-Int32-Connectivity.md` — Proposed
14. `docs/adr/INDEX.md` — master ADR index table

---

## ADR backfill specifications

Each ADR is for a decision already implemented. Use status **Accepted** (decision already enforced)
and set Compliance cross-reference to the existing skill or test.

| ADR | Decision summary | Evidence location |
|:----|:----------------|:-----------------|
| ADR-001 | Triplet (I,J,V) sparse assembly — no direct indexed insertion in loops | SK-04, `assembleTangentSystem.m` |
| ADR-002 | Trial-commit history pattern — `commitHistory` called once after convergence only | SK-05, `test_history_persistence.m` |
| ADR-003 | Modified Riks / hyperplane constraint — not spherical Riks | SK-03, `Analyst_Report_ArcLength.md` |
| ADR-004 | 2×2 Gauss in-plane × 5 Simpson through-thickness for plastic tangent | SK-01, SK-02, `computeTangentStiffnessAndForce.m` |
| ADR-005 | All arithmetic double; connectivity stored as double; int32 prohibited in index math | SK-04, `fuseNodes.m`, `buildElementCache.m` |

---

## Retroactive closure format (for PHASE_STATE.md history block)

```
## Phase history — retroactive entries (Phase 25 governance cleanup)

| Phase | Dates | Status | Gate 0.5 | Notes |
|:------|:------|:-------|:---------|:------|
| 21 | 2026-03-20 | ABANDONED | N/A | Kinematic Hardening — opened, never closed; restarted in Phase [N] |
| 22 | 2026-03-20 | CLOSED (RETROACTIVE) | Not passed (pre-v4.1) | Legacy migration; brief self-issued by Antigravity |
| 23 | 2026-03-25 | CLOSED (RETROACTIVE) | Not passed (pre-v4.1) | GNI element; GitHub Copilot; retroactive brief filed |
| 24 | 2026-03-25 | CLOSED (RETROACTIVE) | Not passed (pre-v4.1) | ArcLength refactor; GitHub Copilot; retroactive brief filed |
```

---

## Acceptance criteria

All of the following must be true before Phase 25 is closed:
- [ ] `docs/dev_logs/index.md` has a row for every phase 9–24
- [ ] `docs/PROJECT_ROADMAP.md` checkboxes match completion reports
- [ ] `docs/adr/INDEX.md` exists and lists ADR-001 through ADR-005
- [ ] All five ADR files exist and have status Accepted
- [ ] Phase 21 is marked ABANDONED in index and roadmap
- [ ] Retroactive briefs exist for phases 22, 23, 24
- [ ] PHASE_STATE.md contains the retroactive history block
- [ ] Zero unaddressed `file:///` paths in any document (fixed or flagged with SCRIBE comments)

---

*Issued by Lead Architect — [YYYY-MM-DD]*
*Status: PENDING → [COMPLETED — YYYY-MM-DD]*
