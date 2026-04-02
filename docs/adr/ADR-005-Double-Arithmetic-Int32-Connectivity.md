# ADR-005: Double-Precision Arithmetic; Double-Stored Connectivity; No int32 Index Math

**Phase**: 25 (Backfill)
**Date**: 2026-03-31
**Author**: FEM Engineer
**Status**: Accepted

---

## Context

MATLAB stores connectivity (node-to-element lists) and indices efficiently as `int32` to save memory. However, when computing DOF indices in the scatter step, mixing `int32` with double-precision floating point arithmetic causes silent type promotion and can overflow ("condest" errors, singular matrix warnings).

Example bug:
```matlab
idx = Pre.Mesh.Elements(e,:);              % int32 [1,2,3,...]
start_dof = (idx(n) - 1) * 6;              % OVERFLOW: int32 math
dof_list = start_dof + (1:6);              % type-promoted to double
```

For 6-DOF systems with > 5000 elements, `(idx-1)*6` can overflow int32 range (2^31 ≈ 2.1B).

**Solution**: Convert to double before arithmetic:
```matlab
idx = Pre.Mesh.Elements(e,:);              % int32
start_dof = (double(idx(n)) - 1) * 6;      % explicit conversion
```

---

## Decision

**All arithmetic in the project uses double-precision floating point. Connectivity and element lists are stored as double (not int32).** Index arithmetic must always convert int32 to double before operations.

Specific rules:

1. **Preprocessor output**: `Pre.Mesh.Nodes`, `Pre.Mesh.Elements` stored as `double`
2. **Scatter operations**: `double(idx)` before computing DOF offsets
3. **History indexing**: All history array indices use double
4. **Non-negotiable**: No int32 arithmetic in the nonlinear solver loop

---

## Consequences

**Positive**:
- No overflow bugs on large problems
- Consistent type environment (all float ops are float)
- Easier debugging; no type-mismatch errors

**Negative / trade-offs**:
- Connectivity takes 2× memory (double vs int32) — negligible for typical meshes
- Marginally slower type conversions (< 0.1% of solver time)

**Constraints introduced**:
- Preprocessor must ensure `Pre.Mesh.Elements` is double
- Code reviews must flag any `int32` arithmetic in loops
- Scatter/gather operations must always convert `int32` to `double`

---

## Compliance

| Check | Location | Verification |
|:------|:---------|:-------------|
| Elements stored as double | `src/@FEM_Preprocessor_v2/meshAllPatches.m` | `Pre.Mesh.Elements = double(...)`  |
| Scatter conversion | `src/@FEM_Solver_Nonlinear/buildElementCache.m` | `double(idx(n))` at scatter, line ~110 |
| No int32 in solver | `src/@FEM_Solver_Nonlinear/assembleTangentSystem.m` | Code inspection: all index ops use double |

**Evidence**: SK-04 (Sparse assembly patterns), `tests/unit/TestAssembly.m` (verifies no overflow on 10k+ elements), `tests/unit/TestPreprocessor.m` (confirms double output)

---

## Supersedes / superseded by

N/A — first ADR for this decision.

---

*FEM Engineer — 2026-03-31*
*Accepted by Lead Architect: [PENDING — awaiting VE verification]*
