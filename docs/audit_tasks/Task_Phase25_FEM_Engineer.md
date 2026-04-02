# Task Brief — Phase 25: Governance Cleanup (FEM Engineer — ADR Backfill)

**Assigned to**: FEM Engineer
**Issued by**: Lead Architect
**Date issued**: 2026-03-31
**Status**: PENDING
**Formal FEM report required**: NO — governance phase, no src/ changes
**Gate 0.5 required**: YES — brief-bind required before ADR proposal work begins

---

## Gate preconditions
- Gate 0: This brief must exist before ADR backfill work begins
- Gate 0.5: FEM Engineer must quote the Objective below verbatim and receive Architect confirmation

## Objective

Phase 25 is a governance cleanup phase. Your responsibility as FEM Engineer is to **backfill five core architectural decisions as Accepted ADRs**. These decisions are already implemented in `src/` and documented in the Skill Library; this phase captures them formally in the ADR system for future reference and enforcement.

- [ ] Write ADR-001: Triplet sparse assembly pattern
- [ ] Write ADR-002: Trial-commit history pattern
- [ ] Write ADR-003: Modified Riks / hyperplane constraint
- [ ] Write ADR-004: 2×2×5 integration scheme
- [ ] Write ADR-005: Double arithmetic, double connectivity
- [ ] All five ADRs proposed with status Accepted and Compliance cross-reference to existing code/tests

## Scope

**In scope**:
- Five ADR documents (not new code — documentation of existing decisions)
- Session log covering all ADR proposals
- Cross-references to SK-01 through SK-10 and existing unit tests

**Out of scope**:
- Any `src/` or `tests/` modification
- Physics changes
- New element types or integration schemes
- Retroactive task briefs (Architect's responsibility)
- Retroactive sync (Project Scribe's responsibility)

## Deliverables

1. Session log: `docs/dev_logs/sessions/YYYY-MM-DD_Phase25_ADR_Backfill_FEM_Engineer.md`
   - Opened BEFORE proposing ADRs
   - Objective: verbatim from this brief
   - Section 3: "N/A — no physics change; governance documentation phase"
   - Section 4: Design decisions table mapping each ADR to its Skill reference

2. Five ADR files (all with status **Accepted**):
   - `docs/adr/ADR-001-Triplet-Sparse-Assembly.md`
   - `docs/adr/ADR-002-Trial-Commit-History-Pattern.md`
   - `docs/adr/ADR-003-Modified-Riks-Hyperplane-Constraint.md`
   - `docs/adr/ADR-004-Integration-Scheme-2x2x5.md`
   - `docs/adr/ADR-005-Double-Arithmetic-Int32-Connectivity.md`

| ADR | Decision summary | Evidence location |
|:----|:----------------|:-----------------|
| ADR-001 | Triplet (I,J,V) sparse assembly — no direct indexed insertion in loops | SK-04, `assembleTangentSystem.m` |
| ADR-002 | Trial-commit history pattern — `commitHistory` called once after convergence only | SK-05, `test_history_persistence.m` |
| ADR-003 | Modified Riks / hyperplane constraint — not spherical Riks | SK-03, arc-length solver code |
| ADR-004 | 2×2 Gauss in-plane × 5 Simpson through-thickness for plastic tangent | SK-01, SK-02, integration code |
| ADR-005 | All arithmetic double; connectivity stored as double; int32 prohibited in index math | SK-04, `fuseNodes.m`, `buildElementCache.m` |

## Dependencies

Phase 25 is the first phase in the v4.1 system. No prior phase dependencies. Foundation-setting governance work.

---

## Data integrity checks

- [ ] All five ADR files use Template 7 format
- [ ] Each ADR has Context, Decision, Consequences, Compliance sections
- [ ] Each ADR Compliance section cross-references the Skill AND the corresponding src/ evidence
- [ ] All ADRs filed with status "Accepted" (decisions already enforced)
- [ ] No unresolved Proposed ADRs remain after Architect acceptance

---

*Issued by Lead Architect — 2026-03-31*
*Status: PENDING → [Gate 0.5 brief-bind submitted by FEM Engineer]*
