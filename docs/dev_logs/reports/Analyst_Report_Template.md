# Analyst Report: [Analytical Review Title] - Phase [NN]

**Date**: [YYYY-MM-DD]
**Status**: [DRAFT | FINAL | CAUTION]

---

## 1. Physical Objective
Describe what part of the mechanics or mathematics is being reviewed.

## 2. Theoretical Grounding
Reference the literature, textbook, or derivation that serves as the "Ground Truth" for this implementation.

## 3. Discrepancies and Observations
List any identified gaps between the theoretical model and the code implementation. Use a table for clarity if multiple parameters are involved.

| Feature | Theory | Code | Verdict |
| :--- | :--- | :--- | :--- |
| Stress Integration | Backward Euler | Iterative Plane Stress | Match |
| Tangent Consistency | Consistent ATM | Linear Elastic | [MISMATCH] |

## 4. Analytical Findings
Provide a deep dive into the math or physics results. 
- Mention Jacobian determinants, convergence norms, or energy plots.
- Use screenshots/plots where helpful.

## 5. Recommendation
- [ ] **APPROVE**: Physical implementation is correct and robust.
- [ ] **REFINE**: Correctness is acceptable but numerical stability can be improved.
- [ ] **REJECT**: Fundamental physical error detected (requires redesign).

## 6. Signature
-- *FEM Expert Analyst*
