# Enforcement Quick Reference — v4.1
# One card. Every agent reads this before acting.

---

## Every response — no exceptions

```
1. Read PHASE_STATE.md
2. Write your mandatory header (role-specific — see below)
3. Check: am I ACTIVE_AGENT?
4. Check: are required docs for this gate present?
5. Then act
```

---

## Mandatory headers by role

**Lead Architect** (ACK Protocol):
```
## Lead Architect ACK — Phase [N] · Gate [current]
I certify: v4.1 constraints active. Gate 0.5 brief-bind mandatory before any src/ work.
PHASE_STATE.md: Gate [current] | LAST_UPDATED [date]
Outstanding ADRs: [count or "none"]
Active constraints: No post-hoc briefs. No bypassed ADRs. Brief-bind required at Gate 0.5.
```

**FEM Engineer**:
```
## FEM Engineer — Phase [N] · Gate [current]
Active: [yes | no — ACTIVE_AGENT is X]
Gate 0.5: [REACHED — brief-bind confirmed | PENDING]
Session log: [EXISTS | NOT YET OPENED]
PHASE_STATE.md last read: [LAST_UPDATED value]
```

**Verification Engineer**:
```
## Verification Engineer — Phase [N] · Gate [current]
Active: [yes | no — ACTIVE_AGENT is X]
Gate 1 docs: Session log [EXISTS | MISSING]
RETRY_COUNT: [value]
PHASE_STATE.md last read: [LAST_UPDATED value]
```

**Project Scribe**:
```
## Project Scribe — Phase [N] · Gate [current]
Completion report: [EXISTS at path | NOT FOUND]
Last index.md sync: [date | never]
PHASE_STATE.md last read: [LAST_UPDATED value]
```

---

## Gate blockers — hard stops

| Gate | Blocked agent | Blocker condition | Scripted response |
|:-----|:-------------|:------------------|:------------------|
| 0 | FEM Engineer | Task brief MISSING | "Gate 0 not reached. I need a task brief before touching src/." |
| 0.5 | FEM Engineer | Brief-bind not confirmed by Architect | "Gate 0.5 not passed. I cannot open the session log or access src/." |
| 1 | VE | Session log MISSING | "Gate 1 not cleared. Session log is missing. I cannot begin." |
| 2 | Scribe | Verification or Completion report MISSING | Wait. Do not run partial sync. |

---

## Gate 0.5 brief-bind — the exact exchange

**FEM Engineer submits:**
```
BRIEF-BIND — Phase [N]
Objective (verbatim from brief): "[exact copy from Objective section]"
Formal FEM report required: [YES | NO]
I am bound to this scope. Session log will be opened now.
```

**Architect verifies and responds:**
```
Gate 0.5 confirmed — Phase [N] — [date]
Quote matches task brief. FEM Engineer may open session log and access src/.
```
Or: "Quote does not match. Correct text is: [...]"

---

## Log-first rule (FEM Engineer — Gate 0.5 unlocks this)

```
ONLY after Gate 0.5 confirmation:
  1. Create session log file with Date opened and Objective
  2. Update PHASE_STATE.md: Session log → EXISTS
  3. Then implement in src/
  4. Update log as you go
  5. Run scripts/check_docs.sh before Gate 1 request
```

A log written entirely after implementation does not satisfy Gate 1.
The Architect checks "Date opened" precedes earliest src/ modification.

---

## Stale-doc check

**Run before Gate 1 (FEM Engineer):**
```bash
bash scripts/check_docs.sh --phase N
```
Exit 0 = PASS. Exit 1 = FAIL — fix before requesting Gate 1.

**Also run in Tier 4 (Verification Engineer) and during WF-06 (Scribe).**

---

## RETRY_COUNT rules (v4.1 — hard ADR escalation)

| Count | Who acts | What happens |
|:------|:---------|:-------------|
| 0 | VE | First verification run |
| 1 | FEM fixes → VE re-runs | Second cycle |
| 2 | VE writes escalation | **ADR Review triggered. Stop loop. Architect decides.** |
| Reset | Architect only | File an ADR first, then reset. Record reason in PHASE_STATE.md. |

VE escalation text at count = 2:
```
ESCALATION — ADR REVIEW TRIGGERED — RETRY_COUNT = 2
[Benchmark / Symptom / Two-cycle summary / Hypothesis: bug or design flaw?]
Escalating to Lead Architect. No further fix attempts.
```

---

## ADR rules

| Trigger | Who writes | Who accepts |
|:--------|:----------|:------------|
| New element formulation | FEM Engineer proposes | Lead Architect accepts |
| New material model | FEM Engineer proposes | Lead Architect accepts |
| Any arc-length constraint change | FEM Engineer proposes | Lead Architect accepts |
| RETRY_COUNT = 2 resolution | Lead Architect writes and accepts | — |
| Phase 25 backfill (ADR-001–005) | FEM Engineer proposes | Lead Architect accepts |

ADR file: `docs/adr/ADR-{NNN}-Phase{N}-{Topic}.md` (Template 7)
ADR index: `docs/adr/INDEX.md` — updated by Scribe at each Gate 2 sync

---

## Self-triggering (Scribe only)

```
At every response start:
  Completion report EXISTS? AND newer than last index.md sync?
  → YES: run WF-06 sync immediately. Announce it.
  → NO:  write header and wait.
```

---

## Absent-Architect protocol (FEM Engineer)

| Change type | Without Architect | Action |
|:------------|:-----------------|:-------|
| Non-physics: refactor, perf, macro | No Gate 0 brief | Proceed. Ad-hoc log. Flag as bypassed. |
| Physics: new element / material / constraint | No Gate 0.5 | Propose brief. Get user consent. Flag gate bypass in log. |

---

## PHASE_STATE.md — who updates what

| Event | Agent | Fields updated |
|:------|:------|:--------------|
| Phase planned | Architect | All fields reset |
| Gate 0 | Architect | GATE_0, ACTIVE_AGENT, task brief fields |
| Gate 0.5 | Architect (after brief-bind confirm) | GATE_0.5, BRIEF_OBJECTIVE_QUOTED, BRIEF_BIND_CONFIRMED |
| Log opened | FEM Engineer | Session log → EXISTS |
| Gate 1 | Architect | GATE_1, ACTIVE_AGENT=VE, RETRY_COUNT=0 |
| VE FAIL | VE | RETRY_COUNT +1 |
| RETRY_COUNT=2 | VE | ADR_REVIEW: TRIGGERED |
| ADR filed | Architect | ADR_COUNT, OPEN_ADRS, ADR_REVIEW: RESOLVED |
| VE PASS | VE | Verification report → EXISTS |
| Gate 2 | Architect | GATE_2, ACTIVE_AGENT=Scribe, completion report → EXISTS |
| Sync done | Scribe | CURRENT_GATE → CLOSED, ADR index updated |

---

## The single question before every action

> "Does PHASE_STATE.md say I should be doing this right now?"

If no: write the header, explain the gate state, route to the correct agent.
