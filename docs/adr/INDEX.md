# Architecture Decision Records (ADR) Index

**Last updated**: 2026-03-31
**Maintained by**: Project Scribe, Lead Architect
**Governance System**: v4.1 (Deployed 2026-03-31)

---

## Summary

This document indexes all active ADRs (Accepted, Proposed) in the project. Retroactively documented decisions from Phases 3–24 are noted below. Rejected or superseded ADRs are listed in their parent ADR.

---

## Core Architectural Decisions (Phases 3–24 Retroactive + Phase 25)

These 5 ADRs capture the foundational architectural patterns that span the entire project history (Phases 3–25). They were formally documented in Phase 25 but represent decisions made during earlier phases (see "Phases" column).

| ADR# | Title | Status | Phases | Date | Reference |
|:-----|:------|:-------|:-------|:-----|:----------|
| ADR-001 | Triplet-Format Sparse Assembly | Accepted | 9–15 (retroactive) | 2026-03-31 | [ADR-001-Triplet-Sparse-Assembly.md](ADR-001-Triplet-Sparse-Assembly.md) |
| ADR-002 | Trial-Commit History Pattern | Accepted | 10–16 (retroactive) | 2026-03-31 | [ADR-002-Trial-Commit-History-Pattern.md](ADR-002-Trial-Commit-History-Pattern.md) |
| ADR-003 | Modified Riks / Hyperplane Constraint | Accepted | 11–18 (retroactive) | 2026-03-31 | [ADR-003-Modified-Riks-Hyperplane-Constraint.md](ADR-003-Modified-Riks-Hyperplane-Constraint.md) |
| ADR-004 | Integration Scheme — 2×2 Gauss × 5 Simpson | Accepted | 8–14 (retroactive) | 2026-03-31 | [ADR-004-Integration-Scheme-2x2x5.md](ADR-004-Integration-Scheme-2x2x5.md) |
| ADR-005 | Double-Precision Arithmetic; Double-Stored Connectivity | Accepted | 3–24 (retroactive) | 2026-03-31 | [ADR-005-Double-Arithmetic-Int32-Connectivity.md](ADR-005-Double-Arithmetic-Int32-Connectivity.md) |

---

## Retroactive Governance Coverage

### Phases 3–24: Pre-v4.1 Governance
All architectural decisions from Phases 3–24 are acknowledged via the Core ADRs above and documented in the Skill Library (SK-01 through SK-10). A comprehensive retroactive governance index is available at:

**`docs/audit_tasks/Retroactive_Governance_Index.md`**

### Phase 21: Abandoned
Phase 21 was not executed. Formal abandonment documentation:

**`docs/audit_tasks/Task_Phase21_Abandonment.md`**

### Phase 25+: Full v4.1 Governance
Future phases will follow complete v4.1 gate discipline with formal briefs, brief-bind, verification, and ADR documentation.

---

## Skill Library Cross-Reference

| Skill | ADRs | Purpose |
|:------|:-----|:--------|
| SK-01 | ADR-004 | Shell element formulation with 2×2×5 integration |
| SK-02 | ADR-004 | J2 plasticity return mapping |
| SK-03 | ADR-003 | Arc-length solver with Modified Riks constraint |
| SK-04 | ADR-001, ADR-005 | Triplet sparse assembly; double arithmetic patterns |
| SK-05 | ADR-002 | Trial-commit history management |
| SK-06–SK-10 | [Reserved] | Future ADRs as codebase evolves |

---

## How to Use This Index

1. **To find an ADR**: Use the tables above and click the link for the full document.
2. **To add a new ADR**: Update this index, add the ADR file to `docs/adr/`, and use Template 7.
3. **To supersede an ADR**: Update the "Status" field in the ADR to "Superseded", note the replacement ADR, and link from this index.
4. **Retroactive decisions**: Add to "Retroactive Governance Coverage" section and cross-reference in the main table.

---

## ADR Lifecycle

- **Proposed**: Decision under review; awaiting Architect acceptance
- **Accepted**: Decision approved and enforced; evidence in `src/` and tests
- **Superseded**: Previous decision replaced by new ADR; see parent ADR for transition details
- **Rejected**: Decision not adopted; reason documented in ADR file

---

*Maintained by Lead Architect and Project Scribe (v4.1 Governance System)*
*Last governance update: 2026-03-31 (Phase 25 retroactive sync complete)*

