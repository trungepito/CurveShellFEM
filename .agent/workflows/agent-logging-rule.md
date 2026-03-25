---
description: Rule for documenting architectural changes and project progress.
---

# Agent Workflow: Mandatory Project Logging

To ensure a scalable and cooperative development environment, all agents MUST follow this logging procedure upon completing a significant technical task or architectural pivot.

## 1. When to Log
- Completion of a **Phase** (as defined in `task.md`).
- Introduction of a **New Feature** or element type.
- Significant **Refactoring** (e.g., renaming classes, merging components).
- Discovery and resolution of a **Major Bug**.

## 2. Steps to Perform
1.  **Draft a Session Log**: In `docs/dev_logs/sessions/`, create a new markdown file:
    `YYYY-MM-DD_[Topic]_[AgentID].md`
2.  **Update Master Index**: Append the new log entry to `docs/dev_logs/index.md`.
3.  **Promote Knowledge**: If a complex derivation or optimization is discovered, update/create a file in `docs/dev_logs/knowledge_base/`.

## 3. Rationale
**The log replaces manual status reports**. It ensures that multiple agents can cooperate by providing a clear audit trail of why files were renamed or deleted (e.g., the `Curve8Element_NL` $\to$ `Curve8Element_Plastic` migration).
