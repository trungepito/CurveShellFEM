---
name: gni-element-implementation
description: "Use when implementing or modifying GNI (Geometric Nonlinear Incremental) elements in CurveShellFEM. Enforces geometric nonlinearity only, no material plasticity."
applyTo: "src/@Curve8Element*/**"
---

# GNI Element Implementation Instructions

When creating or updating elements for Geometric Nonlinear Incremental (GNI) analysis, follow these rules to ensure consistency, accuracy, and maintainability. GNI focuses on large displacements/rotations with small strains, using Green-Lagrange strains and geometric stiffness.

## Core Rules

1. **Inheritance and Structure**:
   - Inherit from `Curve8Element` base class.
   - Override only `computeTangentStiffnessAndForce` method.
   - Do not add history variables or material models (pure geometric nonlinearity).

2. **Integration Scheme**:
   - Use 2×2 Gauss points for in-plane integration.
   - Use single-point thickness integration (elastic material assumption).
   - Total: 4 integration points (sufficient for thin shells/large displacements).

3. **Strain Computation**:
   - Compute Green-Lagrange strains using von Karman approximation (linear strains + 0.5×slope² for membrane).
   - Include nonlinear B-matrices for membrane contributions.

4. **Stiffness Matrix**:
   - Combine material stiffness (linear) + geometric stiffness (Kg).
   - Ensure KT is 48×48 and F_int is 48×1.
   - Use base class `computeGlobalMatrix6DOF` for global transformations.

5. **Solver Integration**:
   - Add 'GeometricNL' material type check in `buildElementCache`.
   - Ensure compatibility with `FEM_Solver_NL` and `FEM_Solver_ArcLength`.

6. **Testing and Validation**:
   - Add unit tests in `tests/unit` for tangent/internal force accuracy.
   - Include patch tests in `tests/Patchtest` for constant strain/stress states.
   - Run benchmarks in `examples/` (e.g., cylindertest2.m, cantilever snap-through).
   - Verify nonlinear convergence (residual norms, load steps).

7. **Documentation and Workflow**:
   - Follow `add-element-type` workflow.
   - Update `docs/PROJECT_FILE_REFERENCE.md` and `README.md`.
   - Log in `docs/dev_logs/` with phase metadata.
   - Commit with `[Phase XX]` format.

## Anti-Patterns to Avoid

- Do not override `computeGlobalMatrix6DOF` (use base method).
- Avoid adding material history or plasticity logic.
- Do not use simplified code sections; complete all B-matrix assemblies.
- Do not skip unit tests or benchmarks.

## Example Prompt

"Implement a new Curve8Element_GNI class for geometric nonlinearity analysis, following the GNI instructions."
