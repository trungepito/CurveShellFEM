# Audit Findings — Phase Lifecycle Failure Modes
# Evidence drawn from CurveShellFEM session logs, reports, and index (Phases 19–24)
# This document is the evidence base for the v4.0 redesign decisions.

---

## Finding 1 — The Architect stops being the Architect after ~3 exchanges

### Evidence
- Phase 22 (index.md): agent listed as "Antigravity" — the implementer — performing
  "knowledge management" and "migration". No task brief exists in audit_tasks/.
  No Architect delegation record. The Implementer decided the scope unilaterally.

- Phase 23 + 24 (GitHub Copilot): both phases executed by a single external agent
  with no Architect task brief, no Gate 0, no Gate 1 spot-check, and no Gate 2
  sign-off. The completion report (Lead_Architect_Phase9_Completion.md) was
  written AFTER the work, not before it started.

- Phase 21 (index.md): Status = "In Progress", Log = "TBD". Phase was opened and
  never formally closed. No Architect closure report exists.

### Root cause
The Architect role has no self-enforcing trigger. When the user starts describing
a problem directly to Claude, Claude responds as a problem-solver, not as the
Architect. The role persona evaporates within 2–3 conversational turns.

---

## Finding 2 — Gate 0 is never actually a gate

### Evidence
- No audit_tasks/ file exists for Phases 22, 23, or 24 in the provided documents.
- Phase 24 session log shows the ArcLength refactor was completed AND the task
  brief was written in the same document — work preceded the brief.
- Architect_Audit_Phase5.md says "I am calling the following agents to perform
  immediate reviews" but there is no corresponding Task_Phase5_*.md for any agent.

### Root cause
Gate 0 is described as "write a task brief before work begins" but nothing
prevents work from beginning without it. The instruction is advisory, not
structural. An agent receiving a natural-language request will act on it.

---

## Finding 3 — Session logs and reports are written retroactively or not at all

### Evidence
- All five reports dated 2026-03-27 (Analyst, Implementer, Validator, Systems,
  Visualization) were filed in a single session AFTER the phases they document.
  Internal evidence: cross-references between reports use identical phrasing,
  suggesting one agent authored all five in one pass.
- Phase 21 session log entry in index.md: "TBD" — never written.
- The agent-logging-rule.md says "create a session log after any major change"
  but provides no enforcement mechanism for before-the-fact logging.

### Root cause
Logging is a post-hoc obligation with no structural trigger. When momentum is
high (bug to fix, benchmark to run), logging gets deferred and is never fully
caught up.

---

## Finding 4 — The failure loop has no timeout

### Evidence
- Validation_Report_ArcLength_Failure.md documents a FAIL verdict.
- Validation_Report_Phase5.1_FIX.md documents the resolution.
- There is no record of how many cycles occurred between the two, who escalated,
  or whether the Architect was involved. The loop resolved informally.

### Root cause
The charter says "after two cycles, escalate to Architect" but there is no
mechanism to count cycles or trigger escalation. Escalation is discretionary.

---

## Finding 5 — The Scribe has no reliable trigger

### Evidence
- PROJECT_ROADMAP.md shows Phase 10 as "[ ] PROPOSED" despite
  Lead_Architect_Phase10_Completion.md existing and explicitly stating "COMPLETED".
- dev_logs/index.md has no entry for Phase 22.
- File links in multiple reports use file:/// absolute paths pointing to a
  specific Windows machine (d:/Works/2025 Industry Project/...), meaning the
  Scribe never ran a link audit on those documents.

### Root cause
The Scribe is triggered "by Gate 2" but Gate 2 is itself not reliably reached
(Finding 2). The Scribe has no way to detect Gate 2 occurred if the Architect
forgot to announce it.

---

## Finding 6 — Agent identity collapses under direct user requests

### Evidence
- Session_Report_2026_03_27.md lists five agents as contributors but prose
  style, vocabulary, and cross-referencing across all five reports is consistent
  with a single author.
- The "Lead Architect" in Architect_Audit_v2.md writes "I am calling the
  following agents" then immediately describes what those agents found — with
  no intervening exchange between agents.
- GitHub Copilot is listed as an agent for Phases 23–24 but has no instruction
  file, no agent profile, and no task brief. It is effectively an anonymous
  contributor with no role constraints.

### Root cause
In a single-model agentic system, all roles are played by the same model in the
same context. Without a structural forcing function that makes the model CHECK
ITS ROLE before each response, the role dissolves under conversational pressure.

---

## Summary — the six failure modes

| # | Failure | When it happens | Effect |
|:--|:--------|:----------------|:-------|
| 1 | Architect persona evaporates | After 2–3 direct user requests | No delegation, no gates |
| 2 | Gate 0 not enforced | User describes work directly | Work starts without brief |
| 3 | Logs written retroactively | When momentum is high | Inaccurate or missing audit trail |
| 4 | Failure loop has no timeout | Fix takes multiple cycles | Architect never re-engaged |
| 5 | Scribe has no reliable trigger | Gate 2 skipped | Roadmap and index drift |
| 6 | Agent identity collapses | Any multi-turn conversation | All roles blend into one |

---

## Design principles derived from findings

**P1** — Every response begins with a role check. Mandatory structured header forces
the model to retrieve its current gate and active-agent context before answering.

**P2** — Gates are enforced by document existence, not by instruction. Gate 0 cannot
pass if the task brief file does not exist. Gate 1 cannot pass if the session log
does not exist. These are scripted refusals, not recommendations.

**P3** — Logging is a precondition, not a postcondition. The session log is opened
(minimum: header + objective) before any src/ code is written.

**P4** — The failure loop is counted and time-bounded. RETRY_COUNT in PHASE_STATE.md.
After count = 2, the Verification Engineer escalates automatically — not discretionally.

**P5** — The Scribe triggers on document detection, not on announcement. Checks at
every response start whether completion report exists and is newer than last index sync.

**P6** — Phase state is always visible in one place. PHASE_STATE.md at project root
reflects current phase, gate, active agent, retry count, and document status.
Every agent reads it before acting.
