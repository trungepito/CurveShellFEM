# Phase 13: Preprocessor Modularization & Graded Meshing

## 1. Phase Definition
- **Goal**: Resolve structural bloat in `@FEM_Preprocessor_v2` by explicitly isolating geometry creation from meshing. Introduce schema-validation guardrails to prevent downstream solver errors. Enable non-uniform graded meshing capabilities to accurately resolve highly concentrated stress fields.
- **Dependencies**: Relies on successful completion of Phase 12 (Core Solver Refactoring and Vectorization), which is **DONE**. 

## 2. Task Decomposition & Agent Assignments

### Systems & Consistency Engineer
To ensure input/output predictability across all phases.
- [ ] **Task SE-1 (Schema Validation)**: Create `validatePreprocessorOutput(obj, Pre)` in `@FEM_DataManager` to enforce strict formatting requirements (Data types, bounds) on `Pre.BCs`, `Pre.Loads`, and `Pre.Mesh`.
- [ ] **Task SE-2 (Pipeline Integration)**: Integrate this validation call directly before the Nonlinear solvers initiate their arc-length algorithms to catch modeling errors instantly.

### Core Implementer (Antigravity)
To ensure high-performance execution speed and code cleanliness.
- [ ] **Task Core-1 (Geometry Isolation)**: Extract specialized CAD generation routines (`createExtrusion`, `createIBeam`, etc.) into a standalone factory class (`GeometryEngine`) to severely reduce the line-count of `FEM_Preprocessor_v2.m`.

### Preprocessor Specialist
To handle advanced geometric constraints and generation logic.
- [ ] **Task PS-1 (Graded Meshing)**: Modify `meshQuadPatch.m` to accept optional `edgeBias` parameter arrays, generating clustered serendipity elements rather than uniform spacing via Coons patch interpolation.
- [ ] **Task PS-2 (Distortion Diagnostics)**: Implement a generic `checkMeshDistortion.m` routine verifying the geometric Jacobians of the mesh to warn against inverted or severely distorted shells resulting from biased parameters.

### Validation Scientist
To verify mathematical rigidity.
- [ ] **Task VS-1 (Benchmark Creation)**: Create `tests/test_graded_mesh.m` proving that `edgeBias` settings dynamically scale elements correctly without violating assembly norms.
- [ ] **Task VS-2 (Distortion Validation)**: Create `tests/diag_distorted_mesh.m` verifying that intentionally degenerated meshes correctly trip the `checkMeshDistortion.m` alert.

## 3. Communication
- All tasks must log their completion in `docs/dev_logs/logs/` following the Reporting Protocol.
- Upon completion of Phase 13, the **Documentation Assistant** will generate the master completion report.
