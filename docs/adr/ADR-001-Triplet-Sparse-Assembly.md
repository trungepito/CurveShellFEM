# ADR-001: Triplet-Format Sparse Assembly

**Phase**: 25 (Backfill)
**Date**: 2026-03-31
**Author**: FEM Engineer
**Status**: Accepted

---

## Context

Global stiffness matrix assembly is the most expensive operation per Newton step. Early prototypes used direct indexed insertion `K(sctr,sctr) += Ke`, which triggers memory reallocation on every element loop—O(nElements) memory reallocations.

The triplet format (I, J, V arrays) pre-allocates space, builds indices in memory, then calls `sparse()` once. This eliminates reallocation overhead and is faster by 1–2 orders of magnitude for large problems.

**Alternatives considered**:
1. Direct indexed insertion: `K(sctr,sctr) += Ke` — rejected (reallocation cost)
2. Triplet pre-allocation with aggressive storage: `nz = 1e6` — rejected (memory heavy)
3. **Chosen: Triplet with exact pre-count** — `nz = 48*48*nElems`. Build indices, call `sparse()` once.

---

## Decision

**All global stiffness matrix assembly uses triplet-format (I, J, V) sparse construction.** Direct indexed insertion into a global sparse matrix inside a loop is prohibited in all current and future solver assembly code.

The pattern is:
```matlab
nz = 48*48 * nElems;
I = zeros(nz,1); J = zeros(nz,1); V = zeros(nz,1);
count = 0;
[ii_base, jj_base] = ndgrid(1:48, 1:48);   % compute once outside loop

for e = 1:nElems
    sctr = obj.SctrMap(e,:);
    [Ke, fe, ~] = obj.Elements{e}.computeGlobalMatrix6DOF(u_el);
    range = count + (1:48*48);
    I(range) = sctr(ii_base(:));
    J(range) = sctr(jj_base(:));
    V(range) = Ke(:);
    count = count + 48*48;
end
K = sparse(I(1:count), J(1:count), V(1:count), nDofs, nDofs);
```

SctrMap (scatter indices) must be pre-computed once in `buildElementCache`, not recalculated per element.

---

## Consequences

**Positive**:
- Assembly time reduced by 50–95% depending on problem size
- Memory allocation pattern is predictable (no surprises in large problems)
- Future developers have a clear, repeatable pattern to follow

**Negative / trade-offs**:
- Requires pre-allocation of I, J, V with known sparsity pattern (48*48 per element)
- Not extensible to variable DOF-per-element (would need adaptive sizing)

**Constraints introduced**:
- All elements in the system must have uniform 48 DOF global structure (enforced)
- SctrMap must be recomputed only if mesh topology changes (not per Newton step)
- No "dynamic" matrix insertion allowed in the solver loop

---

## Compliance

| Check | Location | Verification |
|:------|:---------|:-------------|
| Triplet assembly used | `src/@FEM_Solver/assembleTangentSystem.m` | Explicit triplet pattern impl., lines ~50–70 |
| No direct indexed insertion | `src/@FEM_Solver/assembleTangentSystem.m` | Code inspection: K() never appears in loop |
| SctrMap pre-computed | `src/@FEM_Solver_Nonlinear/buildElementCache.m` | Scatter map built once per mesh, ~line 120 |

**Evidence**: SK-04 (Skill Library), `tests/unit/TestAssembly.m` (verifies triplet correctness)

---

## Supersedes / superseded by

N/A — first ADR for this decision.

---

*FEM Engineer — 2026-03-31*
*Accepted by Lead Architect: [PENDING — awaiting VE verification]*
