# Task Brief — Phase 25: Governance Cleanup (Verification Engineer — Minimal Verification)

**Assigned to**: Verification Engineer
**Issued by**: Lead Architect
**Date issued**: 2026-03-31
**Status**: PENDING
**Formal report required**: NO — governance phase

---

## Objective

Phase 25 is a governance cleanup phase. Your responsibility as Verification Engineer is **minimal verification of administrative correctness**—not technical verification. Most of Phase 25 is the Project Scribe's responsibility (retroactive sync). Your role is a final gate check:

- [ ] Confirm that all five ADRs are written with consistent format (Template 7)
- [ ] Confirm each ADR Compliance section points to actual evidence (Skills and src/ code)
- [ ] Confirm Session log exists and is properly dated before ADR proposal work
- [ ] Confirm all retroactive briefs exist (Architect's deliverable)
- [ ] Confirm `docs/adr/INDEX.md` has all five ADRs listed
- [ ] Confirm zero unaddressed `file:///` paths in new/updated documentation

## Scope

**In scope**:
- Registry checks (ADR index, template consistency)
- Link verification (Skills exist, src/ files cited exist)
- Documentation completeness
- `file:///` path audit

**Out of scope**:
- Benchmarks (Phase 25 has none)
- Unit tests (Phase 25 has none)
- Physics validation (Phase 25 has none)
- `src/` execution (Phase 25 has no code changes)

## Acceptance criteria

All of the following must be true before Phase 25 passes verification:

- [ ] `docs/adr/INDEX.md` exists and lists ADR-001 through ADR-005
- [ ] All five ADR files exist at their expected paths in `docs/adr/`
- [ ] Each ADR has complete sections: Context, Decision, Consequences, Compliance
- [ ] Each ADR Compliance section names a Skill file (SK-NN) and references a src/ file or test
- [ ] FEM Engineer session log exists with "Date opened" field pre-dating ADR proposal
- [ ] Session log Objective section matches task brief verbatim
- [ ] Four retroactive task briefs exist (phases 22, 23, 24, plus the one for 21 abandonment handling — Architect's deliverable)
- [ ] Project Scribe deliverables exist:
  - `docs/dev_logs/index.md` updated with entries for phases 9–24
  - `docs/PROJECT_ROADMAP.md` checkboxes corrected
  - `docs/PROJECT_PLAN_REFACTORED.md` status fields updated
  - Phase 21 marked ABANDONED
- [ ] Zero unaddressed `file:///` absolute paths in any document (all flagged with `<!-- SCRIBE: -->` comments or converted to relative paths)

## Verification report checklist

File: `docs/dev_logs/reports/Verification_Report_Phase25_Governance.md`

- [ ] ADR registry: 5 ADRs found, all formatted correctly
- [ ] Link audit: all Skill and src/ references verified as reachable
- [ ] Session log: exists, dated before ADR work
- [ ] Retroactive deliverables: all present
- [ ] Stale-doc check: N/A (Phase 25 has no src/ changes — no check required)
- [ ] `file:///` paths: [count] flagged, [count] converted
- [ ] Verdict: PASS

---

*Issued by Lead Architect — 2026-03-31*
*Status: PENDING → [Gate 1 reached]*
