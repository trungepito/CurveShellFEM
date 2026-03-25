# Workflow: Material Nonlinearity Expansion (J2 Plasticity)

This workflow guides the implementation of elastoplastic analysis in CurveShellFEM using J2 Plasticity and Isotropic Hardening.

// turbo-all

## Phase 1: Material Engine Implementation
1.  Create or update `@Material_J2Plastic/Material_J2Plastic.m`.
2.  Implement `integrateStress`: must handle the iterative Plane Stress return mapping (Newton-Raphson within the Gauss point).
3.  Implement `getConsistentTangent`: must return the algorithmic tangent $D_{ep}$.

## Phase 2: Stateful Element Implementation
1.  Create `@Curve8Element_Plastic/Curve8Element_Plastic.m`.
2.  Add `History` property to store plastic strain ($\epsilon_p$) and equivalent plastic strain ($p$) at every integration point.
3.  Implement `computeTangentStiffnessAndForce`:
    *   Initialize Simpson integration (5 or 7 points through thickness).
    *   Loop through layers, call `Material_J2Plastic.integrateStress`.
    *   Aggregating stress results into $N, M, Q$ (Resultants).
    *   Assemble the $40 \times 40$ local tangent matrix.

## Phase 3: Solver Integration
1.  Update `FEM_Solver_NL` or create a `solvePlasticity` method.
2.  Implement a **State Commitment** mechanism:
    *   Store "Trial" state during Newton-Raphson iterations.
    *   Permanently "Commit" the state variables only after the increment converges.

## Phase 4: Verification & Benchmarking
1.  Create `tests/benchmarks/BenchmarkPlasticity.m`.
2.  Run a 1-element tension test to verify the hardening slope.
3.  Run the "Plastic Hinge" cantilever test.
