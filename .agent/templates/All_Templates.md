# Report & Task Templates (v3.0)

Copy the relevant template. Replace all `[...]` placeholders. Delete unused optional sections.

---

## Template 1 — Task Brief

**File**: `docs/audit_tasks/Task_Phase{N}_{Agent}.md`

```markdown
# Task Brief — Phase [N]: [Topic]

**Assigned to**: [FEM Engineer | Verification Engineer]
**Issued by**: Lead Architect
**Date**: YYYY-MM-DD
**Status**: [ ] PENDING

---

## Objective
[2–4 bullet points. What must be true when this task is done?]

- [ ] [Deliverable 1]
- [ ] [Deliverable 2]
- [ ] [Deliverable 3]

## Scope
[What is in scope. What is explicitly out of scope for this phase.]

## Required output
- **Session log**: `docs/dev_logs/sessions/YYYY-MM-DD_Phase{N}_{Topic}_FEM_Engineer.md`
- **Report**: `docs/dev_logs/reports/[FEM|Verification]_Report_Phase{N}_{Topic}.md`

## Acceptance criteria  ← (Verification Engineer brief only)
| Benchmark | Metric | Target |
|:----------|:-------|:-------|
| [Scordelis-Lo] | [Max disp error] | [< 0.2%] |
| [Snap-through] | [p > 0 after yield] | [confirmed] |

## Dependencies
[What must be complete before this task starts. "None" if Gate 0.]

---
*Issued by Lead Architect — YYYY-MM-DD*
```

---

## Template 2 — FEM Engineer Session Log

**File**: `docs/dev_logs/sessions/YYYY-MM-DD_Phase{N}_{Topic}_FEM_Engineer.md`

```markdown
# Phase [N]: [Topic] — Session Log

**Date**: YYYY-MM-DD
**Agent**: FEM Engineer
**Status**: Completed

---

## Summary
[One paragraph: what was built or changed and why.]

## Mathematical derivation / physics record
[Required for new elements, materials, constraint functions, integration scheme changes.
 For refactors, write "N/A — no physics change."]

### Reference
[Author, year, equation numbers — e.g. Crisfield (1981), Eq. 3.4–3.7]

### Derivation
[Key equations, sign convention confirmation, integration scheme choice.]

### Deviations from reference
[Any place the implementation intentionally differs from the reference, and why.]

## Files changed

| File | Action | Notes |
|:-----|:-------|:------|
| `src/@ClassName/method.m` | Created | [brief note] |
| `src/@Other/method.m` | Modified | [brief note] |
| `src/@Legacy/` | Deleted | [replaced by...] |
| `tests/unit/TestX.m` | Created | [what it tests] |

## Design decisions
[Non-obvious choices and their rationale. Reference prior reports or skills where applicable.]

## Known limitations / follow-up
- [Item 1 — severity: low/medium/high]
- [Item 2]

## Test results
- `runtests('tests/unit')`: [N passed, 0 failed]
- `runtests('tests/Patchtest')`: [N passed, 0 failed]
```

---

## Template 3 — FEM Engineer Report (physics changes only)

**File**: `docs/dev_logs/reports/FEM_Report_Phase{N}_{Topic}.md`

Required only when: new element class, new material model, arc-length constraint change, integration scheme change, or Verification Engineer-requested root cause analysis.

```markdown
# FEM Report: [Topic] — Phase [N]

**Agent**: FEM Engineer
**Date**: YYYY-MM-DD
**Phase**: [N]
**Verdict**: SELF-APPROVED | REQUIRES-REVIEW

---

## Physical objective
[What formulation is being introduced or changed?]

## Theoretical reference
[Author, year, specific equations. This is the ground truth.]

## Theory vs. implementation

| Feature | Theory | Implementation (file:line) | Match? |
|:--------|:-------|:--------------------------|:-------|
| [Residual sign] | `F_int − λF_ext` | `arcLengthStep.m:88` | Yes |
| [ATM consistency] | Consistent tangent | Exact algorithmic tangent | Yes |

## Key derivation
[Mathematics. Enough detail that the Verification Engineer can construct a diagnostic test.]

## Self-review checklist
- [ ] Stiffness matrix symmetric (error < 1e-14 × max diagonal)
- [ ] Correct zero-energy mode count
- [ ] Patch test prediction stated
- [ ] Residual sign verified
- [ ] Free-DOF partition confirmed
- [ ] commitHistory called correctly
- [ ] `double` used for all arithmetic

## Risks and limitations
- [Risk 1 — priority: HIGH | MEDIUM | LOW]

---
*FEM Engineer — YYYY-MM-DD*
```

---

## Template 4 — Verification Report

**File**: `docs/dev_logs/reports/Verification_Report_Phase{N}_{Topic}.md`

```markdown
# Verification Report: [Topic] — Phase [N]

**Agent**: Verification Engineer
**Date**: YYYY-MM-DD
**Phase**: [N]
**Verdict**: PASS | FAIL | PASS WITH NOTES

---

## Scope
[What was verified. Which task brief this covers.]

## Tier results

| Tier | Tests run | Passed | Failed | Notes |
|:-----|:----------|:-------|:-------|:------|
| 1 Unit | [N] | [N] | 0 | — |
| 2 Patch | [N] | [N] | 0 | — |
| 3 Benchmarks | [list] | [list] | [list] | — |
| 4 Data integrity | [list] | [list] | [list] | — |

## Benchmark detail

### [Benchmark name]
- **Script**: `examples/[script].m`
- **Reference**: [source]
- **Mesh**: [N×M, element type]
- **Solver**: [config]
- **Result**: [value]
- **Target**: [value]
- **Error**: [%]
- **Status**: PASS | FAIL

[Repeat for each benchmark.]

## Data integrity results
[List each invariant checked and its result. Note any fixes applied directly.]

## Failure log (if any)

| Benchmark | Symptom | FEM Engineer diagnosis | Fix | Re-run result |
|:----------|:--------|:----------------------|:----|:--------------|
| [name] | [symptom] | [diagnosis] | [fix ref] | PASS |

## Physics consultation record (if any)
**Question**: [what was asked]
**FEM Engineer answer**: [answer]

## Post-processing outputs
- [Load-displacement curve: description]
- [Yield front plot: description]
- [Other: description]

## Verdict
**[PASS | FAIL | PASS WITH NOTES]**
[One-sentence justification. For PASS WITH NOTES, list what to watch in the next phase.]

---
*Verification Engineer — YYYY-MM-DD*
```

---

## Template 5 — Architect Phase Completion Report

**File**: `docs/dev_logs/reports/Architect_Phase{N}_Completion.md`

```markdown
# Architect Report: Phase [N] Completion

**Date**: YYYY-MM-DD
**Phase**: [N] ([Name])
**Status**: COMPLETED
**Approval**: Lead Architect

---

## Executive summary
[One paragraph: what was achieved, what risk was addressed, what is now possible.]

## Key accomplishments

| Component | Achievement | Verification evidence |
|:----------|:------------|:---------------------|
| [Component] | [What was done] | [Benchmark result or test count] |

## Deliverables audit
- [x] **FEM Engineer session log**: [relative path]
- [x] **FEM Engineer report** (if required): [relative path or "N/A — no physics change"]
- [x] **Verification report**: [relative path] — Verdict: [PASS]

## Numerical highlight
[One key number: e.g., "Scordelis-Lo error: 0.12% on 20×20 mesh."]

## Architectural notes
[Design decisions made this phase and their long-term implications.]

## Authorization for Phase [N+1]
[Explicit statement naming the next phase and its primary goal.]

---
*Lead Architect — YYYY-MM-DD HH:MM*
```
