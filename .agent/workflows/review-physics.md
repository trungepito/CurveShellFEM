---
description: "Use when reviewing the physical and mathematical correctness of a specific FEM part (Material, Element)."
applyTo: "src/**"
---

# Review Physics Workflow (FEM Expert Analyst)

## Objective
Verify that the numerical implementation correctly reflects the underlying continuum mechanics and finite element theory.

## Steps

1. **Constitutive Model Review** (if applicable):
   - Check stress integration algorithm (Radial Return, Backward Euler).
   - Verify Algorithmic Tangent Modulus (ATM) consistency with the integrated stress.
   - Look for non-uniqueness or stability issues in the local loop.

2. **Element Formulation Review**:
   - Inspect shape function derivatives and Jacobian computation.
   - Verify integration scheme (locking prevention, zero energy modes).
   - Check coordinate transformations (Global-to-Local and Frame rotational objectivity).

3. **Invariance and Symmetry Check**:
   - Ensure material frame indifference (objectivity).
   - Verify stiffness matrix symmetry (for conservative systems).
   - Check if isotropic models truly behave isotropically.

4. **Consistency check**:
   - Compare discretization with textbook/scientific paper definitions.

## Verification Checklist
- [ ] Sign conventions verified.
- [ ] ATM derived analytically and implemented exactly.
- [ ] Frame objectivity confirmed.
- [ ] Symmetry of the element stiffness matrix (Ke) checked.
- [ ] Jacobian is strictly positive throughout.
- [ ] Report generated using `Analyst_Report_Template.md`.
