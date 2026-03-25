---
name: arclength-solver-refactoring
description: "Use when refactoring or modifying the ArcLength solver in CurveShellFEM. Enforces integration of sample logic with Adaptive structure."
applyTo: "src/@FEM_Solver_ArcLength/**"
---

# ArcLength Solver Refactoring Instructions

When refactoring the ArcLength solver, follow these rules to integrate the sample's advanced logic with the Adaptive solver's robust structure. This ensures a modular, event-driven, and adaptive arc-length implementation.

## Core Rules

1. **Inheritance Structure**:
   - Inherit from `FEM_Solver_Adaptive` instead of base `FEM_Solver`.
   - Leverage stage-based solving, event notifications, and adaptive stepping.

2. **Algorithm Integration**:
   - Adopt sample's modular constraint system (Riks, LoadControl, DispControl).
   - Implement predictor-corrector with proper tangent computation.
   - Use function handles for residual/tangent evaluation.

3. **Stage-Based Solving**:
   - Each `LoadingStage` specifies arc length parameters (radius, min/max, constraint type).
   - Integrate with Adaptive's bisection logic for failure recovery.
   - Use `solveArcLengthStage()` method for individual stage handling.

4. **Adaptive Arc Length**:
   - Implement automatic arc length reduction on convergence failure (like sample).
   - Increase arc length on easy convergence.
   - Respect min/max bounds from stage configuration.

5. **Constraint Types**:
   - Implement `crisfieldConstraint()`, `loadControlConstraint()`, `dispControlConstraint()`.
   - Support selection via `ConstraintType` property ('Riks', 'LoadControl', 'DispControl').
   - For displacement control, use `ControlDOF` property.

6. **Event Integration**:
   - Fire events for step convergence, arc length adaptation, and failures.
   - Use Adaptive's history management for arc length values.

7. **Error Handling**:
   - Handle singular matrices and convergence failures gracefully.
   - Implement trial-based arc length reduction (up to 5 trials).
   - Provide clear error messages and recovery options.

## Anti-Patterns to Avoid

- Do not maintain monolithic structure; break into modular methods.
- Avoid fixed arc length; implement adaptive scaling.
- Do not ignore Adaptive's event system; integrate fully.
- Do not duplicate code from sample; adapt cleanly.
- Do not skip constraint function validation.

8. **Documentation**:
   - Update `docs/PROJECT_FILE_REFERENCE.md` and `README.md`.
   - Log in `docs/dev_logs/` with phase metadata.
   - Commit with `[Phase XX]` format.

## Documentation Requirements

1. **Code Comments**:
   - Document each constraint function with algorithm references.
   - Explain predictor-corrector logic and arc length adaptation.
   - Include mathematical formulations for constraints.

2. **Class Documentation**:
   - Update class header with inheritance and key features.
   - Document new properties (ConstraintType, ControlDOF, ArcLengthHistory).
   - Reference sample logic and Adaptive structure integration.

3. **Method Documentation**:
   - Document solveArcLengthStage() with stage parameter usage.
   - Explain constraint function signatures and return values.
   - Include examples for different constraint types.

4. **Integration Notes**:
   - Document how ArcLength integrates with LoadingStage system.
   - Explain event firing for monitoring and debugging.
   - Note compatibility with existing solver ecosystem.

## Testing Requirements

1. **Unit Tests**:
   - Test individual constraint functions with known inputs.
   - Validate arc length mathematics and scaling.
   - Test constraint switching (Riks/LoadControl/DispControl).

2. **Integration Tests**:
   - Test full arc length solving with sample problems.
   - Compare results with displacement control for simple cases.
   - Verify adaptive arc length reduction on difficult problems.

3. **Regression Tests**:
   - Ensure existing ArcLength functionality is preserved.
   - Test edge cases (limit points, bifurcations, singular matrices).
   - Validate performance against original implementation.

4. **Benchmark Tests**:
   - Run plastic snap-through with arc length control.
   - Compare convergence rates and solution paths.
   - Test with large models for scalability.

5. **Event Testing**:
   - Verify event firing for step convergence and failures.
   - Test history storage for arc length values.
   - Validate stage-based solving workflow.
