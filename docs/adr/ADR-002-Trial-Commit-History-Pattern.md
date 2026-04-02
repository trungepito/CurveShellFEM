# ADR-002: Trial-Commit History Pattern

**Phase**: 25 (Backfill)
**Date**: 2026-03-31
**Author**: FEM Engineer
**Status**: Accepted

---

## Context

History variables (stress, plastic strain, cumulative plasticity) must persist only when a Newton step converges. If a step fails and retries, the old history must not be overwritten until convergence is confirmed—otherwise, failed trial states corrupt the material state.

Early implementations updated history immediately; diverged steps then left incorrect stress in the elements. Subsequent steps converged to corrupted equilibrium.

The trial-commit pattern separates state update from commitment: compute trial history during assembly, commit only after convergence is confirmed.

**Alternatives considered**:
1. Update history immediately during assembly — rejected (corruption on step failure)
2. Roll back history manually on failure — rejected (error-prone, needs bookkeeping)
3. **Chosen: Trial-commit pattern** — assembly returns trial history. Commit only on convergence.

---

## Decision

**History variables follow the trial-commit pattern.** `commitHistory()` is called exactly once after Newton convergence, not during assembly.

The flow is:
```
assembleTangentSystem() → [KT, F_int, TrialHist]  (trial state computed)
    ↓
newtonLoop() runs iterations
    ↓
convergence achieved? 
  YES → solver.commitHistory(TrialHist)  (history locked in)
  NO  → TrialHist discarded; old HistoryData unchanged
    ↓
next step
```

`commitHistory()` implementation:
```matlab
function commitHistory(obj, TrialHist)
    if isempty(TrialHist), return; end
    for e = 1:length(obj.Elements)
        if isprop(obj.Elements{e}, 'HistoryData') && ~isempty(TrialHist{e})
            obj.Elements{e}.HistoryData = TrialHist{e};
        end
    end
end
```

---

## Consequences

**Positive**:
- Material state corruption prevented (failed steps do not modify history)
- Clear, testable commitment point
- Elastic trial-return can be verified independently

**Negative / trade-offs**:
- Requires allocating TrialHist cell array per assembly (modest memory cost)
- Adds one function call per step (negligible — ~0.1% of assembly time)

**Constraints introduced**:
- `commitHistory()` must be called only after convergence check (enforced in nonlinear solver)
- Assembly must return TrialHist; cannot update history in-place
- Every element with history must support the trial-commit interface

---

## Compliance

| Check | Location | Verification |
|:------|:---------|:-------------|
| Trial history computed | `src/@FEM_Solver_Nonlinear/assembleTangentSystem.m` | TrialHist built as cell array, returned |
| Commit called after convergence | `src/@FEM_Solver_Nonlinear/newtonLoop.m` | `commitHistory()` called line ~85, after tolerance check |
| History not updated in assembly | `src/@Curve8Element/computeTangentStiffnessAndForce.m` | No HistoryData assignment; only TrialHist returned |

**Evidence**: SK-05 (Skill Library), `tests/unit/test_history_persistence.m` (verifies trial-commit ordering)

---

## Supersedes / superseded by

N/A — first ADR for this decision.

---

*FEM Engineer — 2026-03-31*
*Accepted by Lead Architect: [PENDING — awaiting VE verification]*
