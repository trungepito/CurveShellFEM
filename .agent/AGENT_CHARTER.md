# CurveShellFEM — Agent Charter (v3.0)

> This is the single source of truth for every agent, workflow, skill, and template.
> Individual agent files must not contradict this charter. Charter wins on all conflicts.

---

## 1. The Four Agents

| Agent | Pipeline position | Owns |
|:------|:-----------------|:-----|
| **Lead Architect** | Command & gates | Phase planning, delegation, sign-off |
| **FEM Engineer** | Build | Theory derivation + `src/` implementation + unit tests |
| **Verification Engineer** | Verify | Benchmarks, data integrity, post-processing |
| **Project Scribe** | Record | `index.md`, roadmap, session logs — triggered by Gate 2 only |

No other agent roles exist. Work that does not fit cleanly into one of these four is either (a) assigned to the closest fit, or (b) raised with the Lead Architect for explicit delegation.

### Absorbed roles (for reference)
These roles from v2.0 are now absorbed:

| Former role | Now handled by |
|:------------|:--------------|
| FEM Expert Analyst | FEM Engineer |
| Core Implementer | FEM Engineer |
| Preprocessor Specialist | FEM Engineer |
| Validation Scientist | Verification Engineer |
| Systems Engineer | Verification Engineer |
| Visualization Expert | Verification Engineer |
| Documentation Assistant | Project Scribe |

---

## 2. The Three Gates

Every phase passes through exactly three gates. Nothing else triggers a mandatory handoff.

```
Gate 0  →  FEM Engineer works  →  Gate 1  →  Verification Engineer works  →  Gate 2  →  Scribe runs
```

**Gate 0 — Plan approved**
Lead Architect issues one task brief per phase. FEM Engineer may not write `src/` code before Gate 0.

**Gate 1 — Build spot-checked**
Lead Architect confirms: unit tests pass, session log exists, no broken class hierarchy. Takes < 10 min.
Does NOT require a formal physics review report unless the Architect explicitly requests one.

**Gate 2 — Phase signed off**
Lead Architect confirms: all Verification Engineer benchmark targets met, verification report filed.
This event — and only this event — triggers the Project Scribe.

---

## 3. Universal Rules

### 3.1 Who may touch `src/`
Only the **FEM Engineer** writes production code in `src/`. The Lead Architect may write architectural prototypes only when explicitly requested by the user. No other agent modifies `src/`.

### 3.2 Self-review policy
The FEM Engineer may self-review and proceed without a formal analyst report for:
- Refactors with no physics change (class hierarchy, method rename, sparse assembly pattern)
- Preprocessor geometry macros (`createPlate`, `createIBeam`, etc.)
- Performance work (vectorisation, `parfor` conversion) where the Verification Engineer will confirm numerics

A formal physics derivation record **is required** when:
- A new element formulation is introduced (`Curve8Element_*`)
- A new material model is introduced (`Material_*`)
- Any constraint function in the arc-length solver is changed
- The Verification Engineer fails a benchmark and flags a suspected physics bug

### 3.3 Failure path (no Architect involvement required)
When the Verification Engineer fails a benchmark:
1. VE documents the failure in its report and tags the FEM Engineer.
2. FEM Engineer investigates, fixes `src/`, updates unit tests.
3. VE re-runs the benchmark.
4. If pass: VE updates the report and notifies the Architect.
5. If fail again after two cycles: escalate to Architect.

### 3.4 Physics consultation
When the Verification Engineer cannot resolve a physics question (e.g., "is this convergence rate correct for a mixed-basis element?"), it consults the FEM Engineer directly. The answer is recorded in the verification report — not in a separate analyst report.

### 3.5 Project Scribe trigger
The Scribe runs exactly once per phase, triggered by Gate 2. It is never assigned a technical task. It never produces a report of its own.

---

## 4. File Naming Conventions

| Artefact | Pattern | Example |
|:---------|:--------|:--------|
| Task brief | `Task_Phase{N}_{Agent}.md` | `Task_Phase14_FEM_Engineer.md` |
| Session log | `YYYY-MM-DD_Phase{N}_{Topic}_{Agent}.md` | `2026-03-25_Phase24_ArcLength_FEM_Engineer.md` |
| FEM Engineer report | `FEM_Report_Phase{N}_{Topic}.md` | `FEM_Report_Phase9_ANS_EAS.md` |
| Verification report | `Verification_Report_Phase{N}_{Topic}.md` | `Verification_Report_Phase9_ANS_EAS.md` |
| Architect completion | `Architect_Phase{N}_Completion.md` | `Architect_Phase9_Completion.md` |

---

## 5. Directory Map

```
.agent/
  AGENT_CHARTER.md          ← this file
  agents/
    Lead_Architect.md
    FEM_Engineer.md
    Verification_Engineer.md
    Project_Scribe.md
  workflows/
    manage-project.md
    review-architecture.md
    add-element-type.md
    debug-convergence.md
    run-verification.md
    sync-docs.md
  skills/
    SK-01_Shell_Element.md
    SK-02_J2_Plasticity.md
    SK-03_Arc_Length.md
    SK-04_Sparse_Assembly.md
    SK-05_History_Variables.md
    SK-06_Class_Hierarchy.md
    SK-07_Convergence_Diagnosis.md
    SK-08_Benchmark_Setup.md
    SK-09_Mesh_Quality.md
    SK-10_Postprocessing.md
  templates/
    FEM_Report_Template.md
    Verification_Report_Template.md
    Architect_Completion_Template.md
    Task_Brief_Template.md
    Session_Log_Template.md

docs/
  dev_logs/
    index.md
    sessions/
    reports/
    agents/         ← living profile per agent (contributions log)
  audit_tasks/
  PROJECT_ROADMAP.md
  PROJECT_PLAN_REFACTORED.md
```

---

## 6. When to Re-split an Agent

The 4-agent structure becomes insufficient when **both** of the following are true simultaneously:

1. Two independent features are being developed in parallel by different human contributors.
2. The combined workload of FEM Engineer (or Verification Engineer) exceeds what one context window can hold without losing earlier decisions.

In that case, the **first** split to make is extracting Visualization Expert back out of Verification Engineer — the post-processing UI work is most naturally decoupled from numerical verification. The Preprocessor Specialist would be the second split, only if geometry/meshing becomes a dedicated sub-project.

---

## 7. Change History

| Date | Version | Change |
|:-----|:--------|:-------|
| 2026-03-28 | 3.0 | Restructure from 7 agents to 4; pipeline-position model |
| 2026-03-27 | 2.0 | Full ecosystem restructure, charter introduced |
| 2026-03-20 | 1.0 | Initial agent-logging-rule |
