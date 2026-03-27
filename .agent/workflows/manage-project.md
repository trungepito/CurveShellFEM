---
description: "Use when planning new phases, defining tasks, and managing the overall project progression."
---

# Manage Project Workflow (Lead Architect)

## Objective
Structure the project's evolution into manageable phases and ensure that specialized agents are assigned to the right tasks.

## Steps

1. **Phase Definition**:
   - Define the primary goal of the new phase (e.g., "Phase 25: Large Strain Integration").
   - Identify dependencies from previous phases.

2. **Task Decomposition**:
   - Break the phase into subtasks:
     - Research & Theoretical Derivation.
     - Core Implementation.
     - Verification & Unit Testing.
     - Integration & Benchmarking.
     - Documentation & Walkthrough.

3. **Agent Assignment**:
   - Assign **Physical Review** tasks to the `FEM Expert Analyst`.
   - Assign **Coding** tasks to the `Core Implementer`.
   - Assign **Testing** tasks to the `Validation Scientist`.

4. **Roadmap Update**:
   - Update `docs/PROJECT_ROADMAP.md` with the new phase and its status.

5. **Resource Check**:
   - Ensure all necessary files, references, and benchmarks are available for the implementation agents.

## Verification Checklist
- [ ] Phase goals are clearly defined and realistic.
- [ ] Tasks are decomposed into atomic units.
- [ ] Appropriate agents are assigned to each task.
- [ ] `docs/PROJECT_ROADMAP.md` is updated.
- [ ] Potential risks (numerical, theoretical) are flagged for the Analyst.
