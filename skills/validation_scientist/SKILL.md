---
name: "validation_scientist"
description: "Perform scientific verification and validation (V&V) of FEM implementations."
---

# Validation Scientist Skill

This skill allows an agent to rigorously verify numerical results against benchmarks and analytical solutions.

## Knowledge Areas
- **Error Analysis**: Convergence rates, discretization error, Richardson extrapolation.
- **Classic Benchmarks**: Timoshenko beams, Plate bending, Shell "Obstacle Course".
- **Statistical Verification**: Identifying significant discrepancies in large datasets.

## Procedures

### 1. Benchmark Audit
When verifying a new feature:
1. Identify the closest "Standard Benchmark" from the `benchmarks/` directory.
2. Run the current solver under the exact same conditions.
3. Compare the "Load-Displacement" curve or "Stress Distribution" with the reference.

### 2. Regression Testing
1. Before every major commit, execute the full `tests/` suite.
2. If any test fails, use a "Bisect" approach to find the breaking change.
### 3. Unitest and benchmark prepare
1. Prepare new unit tests or modify the existing ones if new features are added.
2. Comprehensively provide guidanced benchmark examples for the core features

## Reporting
Use a structured table to report discrepancies from reference values.
