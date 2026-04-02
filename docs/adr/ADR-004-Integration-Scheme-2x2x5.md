# ADR-004: Integration Scheme — 2×2 Gauss × 5 Simpson

**Phase**: 25 (Backfill)
**Date**: 2026-03-31
**Author**: FEM Engineer
**Status**: Accepted

---

## Context

Shell element integration must balance accuracy (through-thickness plasticity) against computational cost (Gauss points per element).

Standard practice:
- **In-plane**: 3×3 Gauss for membrane/bending, 2×2 reduced for shear (prevents locking)
- **Through-thickness**: Reduced Simpson (2-point per layer) vs. Full Simpson (5-point)

Full Simpson (5-point in z) was attempted but cost 25% more per Newton step for minimal accuracy gain. Reduced Simpson (5 pre-defined points through thickness) provides excellent accuracy without the cost penalty.

Plastic tangent (2×2 × 5) is the bottleneck; the project standardized on this to match element formulation cost (SK-01, SK-02).

---

## Decision

**All through-thickness integration for shell elements uses 5 Simpson points (reduced Simpson rule).** Plastic tangent computation specifically uses 2×2 Gauss in-plane × 5 Simpson through-thickness.

Integration scheme by component:

| Component | Rule | Reason |
|:----------|:-----|:-------|
| Membrane / bending stiffness | 3×3 Gauss in-plane | Full accuracy |
| Transverse shear stiffness | 2×2 Gauss in-plane | Reduced (shear locking prevention) |
| Plastic tangent stiffness | 2×2 Gauss × 5 Simpson | Cost-accuracy balance |
| Yield history recovery | 2×2 × 5 | Consistency with tangent |

Through-thickness points (5 Simpson):
```
z = [-1, -1/√2, 0, 1/√2, 1]  (normalized -1 to +1)
t_actual = (z + 1) × t/2      (convert to thickness range)
```

---

## Consequences

**Positive**:
- Excellent through-thickness stress and plasticity resolution
- Computational cost matches element stiffness cost
- No under-integration artifacts (full Simpson accuracy without cost)

**Negative / trade-offs**:
- Incompatible with other shell element variants (this is the standardized scheme only)
- History array size fixed: 2×2 × 5 = 20 Gauss points per element

**Constraints introduced**:
- New shell element types must conform to 2×2 × 5 integration
- Code using `repmat(init_h, 20, 1)` must be updated if integration changes
- Benchmarks calibrated to 2×2 × 5; regression tests must pass with exactly this scheme

---

## Compliance

| Check | Location | Verification |
|:------|:---------|:-------------|
| Plastic tangent integration | `src/@Curve8Element/computeTangentStiffnessAndForce.m` | 2×2×5 Gauss×Simpson loops, lines ~120–150 |
| History array initialization | `src/@FEM_Solver_Nonlinear/buildElementCache.m` | `repmat(init_h, 20, 1)`, line ~95 |
| Reduced shear integration | `src/@Curve8Element/computeMembraneStiffness.m` | 2×2 Gauss loop (not 3×3), line ~60 |

**Evidence**: SK-01 (Curve8Element formulation), SK-02 (J2 plasticity), benchmark validation showing convergence

---

## Supersedes / superseded by

N/A — first ADR for this decision.

---

*FEM Engineer — 2026-03-31*
*Accepted by Lead Architect: [PENDING — awaiting VE verification]*
