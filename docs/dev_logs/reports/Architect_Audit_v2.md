# Lead Architect: Technical & Architectural Audit (v2.0)

**Date**: 2026-03-27
**Subject**: Project-Wide Technical Debt & Refactoring Strategy

---

## 1. Structural Weaknesses
1. **Element Fragmentation**: The current split between `Curve8Element` and `Curve8Element_Plastic` creates a "combinatorial explosion" risk. If Geometric Nonlinearity (GNI) is added, we would need 4+ classes.
2. **Solver Ambiguity**: `FEM_Solver_NL` and `FEM_Solver_Adaptive` are redundant. `Adaptive` is the modern, stage-based standard and should supersede `NL`.
3. **Leaky Abstractions**: The base `FEM_Solver` contains logic specific to `Curve8Element_Plastic` (e.g., `commitHistory`). This should be handled via a generic `StatefulElement` interface or a material delegate.

## 2. Identified Technical Debt
- **Unused Preprocessors**: `@FEM_Preprocessor` and `@FEM_Preprocessor_CAD` are obsolete compared to `v2`.
- **Duplicate Assembly Kernels**: `assembleinternalforceONLY` vs `assembleTangentSystem`.
- **Inconsistent Initialization**: Some solvers initialize `U` in the constructor, others do it in the `solve` method.

## 3. Proposed Refactoring: Phase 10 (Consolidation)
I recommend a "Spring Cleaning" phase before proceeding to ANS/EAS implementation:

### Item 1: The Unified Element
- Merge all `Curve8Element` variations into a single class.
- Use a `MaterialModel` object to handle elastoplasticity.
- Pass a `NonlinearConfig` struct to `computeStiffnessMatrix` to toggle GNI.

### Item 2: Solver Tiering
- `FEM_Solver`: Strictly for Linear Static.
- `NonlinearSolver (Base)`: Virtual class for NR logic, residual tracking, and line search.
- `FEM_Solver_Adaptive`: Implementation of the stage-based strategy.
- `FEM_Solver_ArcLength`: Implementation of the Crisfield constraint.

### Item 3: Data Integrity
- Centralize state storage in a dedicated `SolverState` object to be passed between elements and solvers.

## 4. Immediate Actions
- [ ] Implement the `Unified Element` prototype.
- [ ] Deprecate `FEM_Solver_NL`.
- [ ] Remove legacy preprocessors from the `src/` directory.

---
*Lead Architect*
