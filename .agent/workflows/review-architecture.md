---
description: "Use when evaluating the structural health of the codebase (modularity, inheritance, interfaces)."
---

# Review Architecture Workflow (Lead Architect)

## Objective
Ensure the codebase remains modular, scalable, and follows the "Lead Architect's" vision for a clean FEM library.

## Steps

1. **Class Hierarchy Audit**:
    - Inspect `@Class` relationships.
    - Check if inheritance is logical (e.g., `ArcLength` inheriting from `Adaptive`).
    - Identify redundant or overlapping classes.

2. **Interface Consistency**:
    - Verify that methods across different solvers/elements use consistent naming and argument structures.
    - Check for proper use of `SolverOptions`, `LoadingStage`, and `Material` objects.

3. **Dependency Mapping**:
    - Identify tight coupling between components.
    - Propose decoupling strategies (e.g., using a `DataManager` or event-driven communication).

4. **Documentation Audit**:
    - Ensure all classes have clear `classdef` comments.
    - Check if `docs/PROJECT_FILE_REFERENCE.md` or similar is up to date.

5. **Performance Bottleneck Research**:
    - (With Core Implementer) Identify architectural choices that limit vectorization or sparse solver efficiency.

## Verification Checklist
- [ ] Class diagrams (Mermaid or similar) are reviewed.
- [ ] Redundant methods identified for refactoring.
- [ ] Interface mismatches documented.
- [ ] Recommendation report created (using `Analyst_Report_Template.md` or architect's note).
