# ADR-{NNN}: [Short decision title]

**Phase**: [N]
**Date**: YYYY-MM-DD
**Author**: [FEM Engineer | Lead Architect]
**Status**: Proposed | Accepted | Rejected | Superseded by ADR-{NNN}

---

## Context

[Describe the problem or situation that required a decision. Include:
- What was the specific challenge?
- What was the technology or architectural context?
- What alternatives were considered?]

**Alternatives considered**:
1. [Option A] — [one-line description]
2. [Option B] — [one-line description]
3. [Chosen option] — [one-line description]

---

## Decision

[State the chosen solution in imperative language. Use "The project uses..."
or "The implementation must..." — never "should", "could", or "might".]

Example: "The project uses triplet-format (I, J, V) sparse assembly for all
global stiffness matrix construction. Direct indexed insertion into a global
sparse matrix inside a loop is prohibited."

---

## Consequences

**Positive**:
- [Benefit 1]
- [Benefit 2]

**Negative / trade-offs**:
- [Limitation 1]
- [Limitation 2]

**Constraints introduced**:
- [Any new rules this decision imposes on future development]

---

## Compliance

How is this decision verified to be enforced in `src/`?

| Check | Location | Verification |
|:------|:---------|:-------------|
| [e.g., Triplet assembly used] | `src/@FEM_Solver/assembleTangentSystem.m` | Unit test `tests/unit/TestAssembly.m` line 45 |
| [e.g., commitHistory called once] | `src/@FEM_Solver/FEM_Solver.m` | SK-05 + `test_history_persistence.m` |

**Verification report cross-reference**: [Verification_Report_Phase{N}_{Topic}.md | not yet verified]

---

## Supersedes / superseded by

[If this ADR supersedes another: "Supersedes ADR-{NNN}: [title]"]
[If superseded: "Superseded by ADR-{NNN}: [title] on YYYY-MM-DD"]
["N/A" if neither applies]

---

*[Author] — YYYY-MM-DD*
*Accepted by Lead Architect: [YYYY-MM-DD | PENDING]*
