# Task: Phase 10 Implementation & Consolidation
**Agent**: Core Implementer
**Priority**: Critical

## Objectives
1. **Unify Curve8Element**:
   - Merge logic from `@Curve8Element_Plastic` into `@Curve8Element`.
   - Implement property-based material model delegation.
2. **Restructure Solver Hierarchy**:
   - Create `FEM_Solver_Nonlinear` base class.
   - Refactor `FEM_Solver_Adaptive` and `FEM_Solver_ArcLength` to inherit from the new base.
3. **Repository Cleanup**:
   - Delete obsolete directories (`@Curve8Element_Plastic`, `@FEM_Solver_NL`, etc.).

## Output
- Consolidated codebase.
- Verification of basic script execution.
