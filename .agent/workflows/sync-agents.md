---
description: "Use when coordinating the efforts of multiple agents on a shared goal."
---

# Sync Agents Workflow (Lead Architect)

## Objective
Ensure that specialized agents (Implementer, Analyst, Validator, Visualizer) are aligned and that information flows smoothly between them.

## Steps

1. **Dependency Identification**:
    - Map which agent's output is required for another's input (e.g., Analyst's review is needed before Implementer's final merge).

2. **Information Handover**:
    - Ensure that reports (from Analyst/Validator) are linked in the `task.md` or session logs for the Implementer to see.
    - Bridge the gap between "Theory" (Analyst) and "Code" (Implementer).

3. **Status Check**:
    - Review the current `task.md` and active session logs of all agents.
    - Identify blocks or misalignments in the project roadmap.

4. **Conflict Resolution**:
    - If a Validator reports a failure that the Implementer cannot reproduce, or the Analyst rejects a formulation the Implementer believes is efficient: The Lead Architect must mediate based on the project's long-term principles.

5. **Roadmap Reconciliation**:
    - Update `docs/PROJECT_ROADMAP.md` based on the combined output of all agents.

## Verification Checklist
- [ ] All agents have clear, non-overlapping tasks.
- [ ] Handover documents (reports, walkthroughs) are linked and reviewed.
- [ ] Roadblocks are identified and mitigated.
- [ ] Master roadmap reflects the current global state of the project.
