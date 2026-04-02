# ADR-003: Modified Riks / Hyperplane Constraint

**Phase**: 25 (Backfill)
**Date**: 2026-03-31
**Author**: FEM Engineer
**Status**: Accepted

---

## Context

Arc-length methods control nonlinear path-following by adding a constraint that couples displacement and load factor increments. Riks originally proposed a spherical constraint; Batoz & Dhatt proposed a hyperplane (linear) constraint—simpler, equally effective.

Two hyperplane variants exist:
1. **Cylindrical hyperplane** (load-proportional): `dup'·(u−u₁) + v·(λ−λ₁) = 0` — decouples displacements and load
2. **Modified Riks** (scaled hyperplane): `dup'·(u−u₁) + ψ²·dlp·(λ−λ₁) = 0` — weights by path scale

The project uses Modified Riks to maintain consistent step behavior as arc-length radius changes; the weighting ψ²·dlp prevents the constraint from becoming numerically stiff on small arc-length steps.

---

## Decision

**The arc-length constraint uses the Modified Riks / hyperplane form, not spherical Riks.**

The constraint is:
```
g = dup'·(u−u₁) + ψ²·dlp·(λ−λ₁) = 0
where u₁ = u₀ + dlp·dup,  λ₁ = λ₀ + dlp
and ψ = 1.0 (user-tunable weight), dlp = arc-length radius
```

Corrector loop on free DOFs:
```matlab
KT_ff·du_I   = fext_f           % tangent load direction
KT_ff·du_II  = -R_f             % equilibrium correction
dλ = -(g + h_f'·du_II) / (s + h_f'·du_I)   where h = dup, s = ψ²·dlp
du(free_dofs) = dλ·du_I + du_II
```

Guard: if `|s| < 1e-14`, set `s = arc_length·ψ²` to prevent denominator collapse on step 1.

---

## Consequences

**Positive**:
- Step consistency maintained across arc-length radius changes
- Snap-back detection naturally emerges (k0 = dot(dup_prev, dup_curr) < 0)
- Load factor can be negative (descending limb, snap-back)

**Negative / trade-offs**:
- Slightly more complex than cylindrical hyperplane
- Requires tuning ψ weight (default 1.0 usually sufficient)

**Constraints introduced**:
- Snap-back must be detected via CSP: `dot(dup_prev, dup_curr)`, never `dot(fext, dup)`
- Residual must be never the full vector; use `norm(R(free_dofs))` for convergence check
- System solved only on free DOFs; fixed DOFs must be zeroed in assembly

---

## Compliance

| Check | Location | Verification |
|:------|:---------|:-------------|
| Constraint implemented | `src/@FEM_Solver_ArcLength/arcLengthStep.m` | Modified Riks formula, lines ~40–60 |
| Snap-back detected via CSP | `src/@FEM_Solver_ArcLength/computeLoadFactor.m` | k0 = dot(dup_prev, dup_curr), line ~25 |
| Free-DOF partition | `src/@FEM_Solver_ArcLength/arcLengthStep.m` | KT(free_dofs, free_dofs) used, line ~55 |

**Evidence**: SK-03 (Skill Library), arc-length solver source code, benchmarks demonstrating snap-back capture

---

## Supersedes / superseded by

N/A — first ADR for this decision.

---

*FEM Engineer — 2026-03-31*
*Accepted by Lead Architect: [PENDING — awaiting VE verification]*
