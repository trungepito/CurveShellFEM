# Session Log: Legacy Cleanup & Architectural Migration
**Date**: 2026-03-20
**Agent**: Antigravity
**Phase**: 22 (Knowledge Management)

## Summary
Performed a system-wide migration to resolve the ambiguity between Geometric and Material nonlinearity by standardizing on the `Curve8Element_Plastic` class.

## Technical Implementation
- **Renamed References**: All occurrences of `Curve8Element_NL` in `tests/` and `src/@FEM_Solver_Adaptive/` have been updated to `Curve8Element_Plastic`.
- **Logic Consolidation**: The `Plastic` subclass is now the sole recipient of history-dependent material integration logic, while the base `Curve8Element` continues to handle geometry and linear elasticity.

## Impact
- **Test Integrity**: Unit tests in `TestElement.m` now correctly exercise the plastic integration paths.
- **Solver Consistency**: The adaptive solver now supports the new plasticity engine.

## Handover
The `Curve8Element_NL` class is now fully deprecated and removed. All future nonlinear development should target the `Plastic` subclass or the base class as appropriate.
