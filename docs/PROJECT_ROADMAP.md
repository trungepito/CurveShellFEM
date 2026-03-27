# CurveShellFEM: Project Roadmap

This roadmap documents the history and planned future of the `CurveShellFEM` project. 
For current detailed execution steps, see the [Refactored Project Plan](file:///d:/Works/2025%20Industry%20Project/CurveShellFEM/docs/PROJECT_PLAN_REFACTORED.md).

## Phase 1: Foundations (Core Math & Utilities)
- [x] Basic Vector/Tensor Math (`MathFEM`).
- [x] Gauss Quadrature schemes.
- [x] Pre-processing foundation (Nodal coordinates, Mesh).

## Phase 2: Linear Elastic Shells
- [x] Shape functions for 8-node curves/shells.
- [x] Linear Stiffness assembly.
- [x] Linear Solver (Displacement Control).
- [x] Basic post-processor (Displacement plots).

## Phase 3: Geometric Nonlinearity (GNI)
- [x] Large deformation kinematics (Green-Lagrange Strain).
- [x] Geometric stiffness matrix ($K_\sigma$).
- [x] Newton-Raphson nonlinear solver.
- [x] Benchmark: Snap-through of curved structures.

## Phase 4: Material Nonlinearity (Plasticity)
- [x] J2 Plasticity (Von Mises) return-mapping algorithm.
- [x] History variable management (`eps_p`, `p`).
- [x] Algorithmic Tangent Modulus (ATM).
- [x] Benchmark: Plastic collapse and hardening.

## Phase 5: Advanced Solvers & Adaptivity
- [x] Arc-Length (Modified Riks) solver remediation.
- [x] History variable persistence bug fix.
- [x] Adaptive load-stepping integration.

## Phase 6: Shell Analysis Benchmarking & Visualization (Current Phase)
- [x] Scordelis-Lo Roof Benchmark (0.12% Error).
- [x] Through-thickness Plastic Yield Visualization.
- [/] Vectorized Assembly Optimization (Initial 20% gain).

## Phase 7: Optimization & Adaptive Refinement
- [x] Low-level vectorization of element GP routines.
- [x] Error estimation based on stress recovery (SPR).
- [x] $h$-adaptive mesh refinement.

## Phase 10: Architectural Consolidation (Cleanup) [CURRENT]
- [ ] Unified 8-node Shell Element (Merge Plasticity).
- [ ] Tiered Nonlinear Solver Hierarchy (`FEM_Solver_Nonlinear`).
- [ ] Repository cleanup (Delete legacy preprocessors).

## Phase 9: Locking Mitigation (ANS/EAS) [PLANNED]
- [ ] Assumed Natural Strain (ANS) for transverse shear.
- [ ] Enhanced Assumed Strain (EAS) for membrane/bending.

## Phase 13: Preprocessor Modularization & Graded Meshing [PLANNED]
- [ ] Refactor geometry primitives into a dedicated `GeometryEngine`.
- [ ] Implement clustered/biased node generation in `meshQuadPatch`.
- [ ] Enforce schema validation on Preprocessor Data tables via `@FEM_DataManager`.
- [ ] Add internal Jacobian diagnostic routines for mesh distortion.

---
*Roadmap managed by the **Lead Architect**.*
