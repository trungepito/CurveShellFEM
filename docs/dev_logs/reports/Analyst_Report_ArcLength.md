# Analyst Report: Physical Review of Arc-Length Solver

**Date**: 2026-03-27
**Agent**: FEM Expert Analyst
**Status**: REVIEW COMPLETED (Minor Mathematical Mismatch Identified)

---

## 1. Mathematical Consistency Audit
The implementation in `FEM_Solver_ArcLength.m` and `arcLengthStep.m` has been reviewed against classical literature (Crisfield 1981, Ramm 1981).

### Findings:
1. **Constraint Type**: The code implements a **Hyperplane (Normal Plane)** constraint:
   $g = \Delta u_{prev} \cdot (u - u_{pred}) + \Delta \lambda_{prev} \cdot (\lambda - \lambda_{pred}) = 0$.
   - *Verdict*: This is a standard and robust variant of the Riks method. However, the documentation (Line 5 of `FEM_Solver_ArcLength.m`) claims it is "Spherical". This is a naming mismatch.
2. **Predictor Strategy**: The Current Stiffness Parameter (CSP) logic correctly uses the dot product of successive tangent predictors to detect snap-back. This is a significant improvement over the previous "norm-only" logic.
3. **Scaling & units**: The implementation implicitly uses a load scaling factor $\psi = 1$. This can lead to ill-conditioning if the displacement magnitudes $(||u||)$ and load factor $(\lambda)$ differ by orders of magnitude (e.g., stiff structures with small deformations).

## 2. Identified Risks
- **Risk 1 (Numerical)**: Near sharp limit points, the hyperplane constraint might struggle with convergence if the step size (arc-length radius) is too large relative to the path curvature.
- **Risk 2 (Conditioning)**: The lack of an explicit $\psi$ parameter makes the solver sensitive to the normalization of the external force vector $f_{ext}$.

## 3. Recommendations
1. **[LOW PRIORITY]** Implement the true **Spherical Riks** constraint (quadratic) as an option for cases where the path has high curvature.
2. **[MEDIUM PRIORITY]** Add an `ArcLengthPsi` property to the `LoadingStage` class to allow user-controlled scaling of the load factor component in the constraint.
3. **[DOCUMENTATION]** Update comments to clarify that the current "Riks" implementation is the "Modified Riks / Normal Plane" variant.

## 4. Final Verdict
**PASS** for general use. The current implementation is stable for the planned plastic snap-through benchmarks, provided the load factor scaling is considered.

-- *FEM Expert Analyst*
