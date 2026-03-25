---
description: Template for adding new element types to the library
---
# Implementing a New Element Type

Follow these standards to ensure compatibility with all solvers:

1. **Create Class Folder**: Use `@Element_Name` in `src`.
2. **Inherit Standard Methods**:
    - `Trans_T()`: Global-to-Local rotation and mapping.
    - `per_5_blkdiag()`: Permutation to align nodes with solver expectations.
3. **Unified Stiffness Method**:
    - `[K, F_int] = computeGlobalMatrix6DOF(obj, u_el)`
    - This method MUST return both stiffness and internal force.
    - If `u_el` is empty, return linear stiffness and zero force.
4. **Gauss Points**: Use `MathFEM.Gauss_p()` to ensure consistent integration rules.
5. **Validation**: Add a unit test in `tests/unit/` using a single-element patch test.
