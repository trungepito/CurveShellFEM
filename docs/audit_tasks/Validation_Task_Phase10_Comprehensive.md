# Validation Task: Comprehensive Phase 10 Audit

**Assignee**: Validation Scientist  
**Priority**: High  
**Status**: [ ] IN-PROGRESS

## 1. Objective
Perform a project-wide audit of the `examples/` directory and prepare a standardized benchmark suite to verify the end-to-end FEM pipeline (Pre -> Solver -> Post) for all supported analysis types.

## 2. Analysis Types to Verify
For each type, ensure there is a corresponding script in `examples/` that is functional and produces verified results:

| Analysis Type | Description | Target Script (Example) |
| :--- | :--- | :--- |
| **Linear** | Standard linear elastic shell analysis. | `benchmark_scordelis_lo.m` |
| **GNA** | Geometric Nonlinear Analysis (Large Displacements). | `benchmark_lee_frame.m` or similar. |
| **GMNA** | Geometric & Material Nonlinear Analysis (Plasticity). | `verify_plastic_viz.m` / `benchmark_plastic_snapthrough.m` |
| **GMNIA** | GMNIA (including Imperfection mapping). | *Required: New or updated script*. |
| **Buckling** | Linear eigenvalue buckling analysis. | `benchmark_buckling_plate.m` |

## 3. Scope of Verification
1.  **Pre-Processor**: Verify nodal and element generation, BC mapping, and Load mapping.
2.  **Solver**: Verify convergence rates, residual norms, and solver-specific parameters (e.g., Arc-Length $\psi$).
3.  **Post-Processor**: Verify stress recovery (SPR), error estimation (ZZ), and visualization (yield front).

## 4. Reporting Requirements
Follow the [Agent Reporting Protocol](file:///d:/Works/2025%20Industry%20Project/CurveShellFEM/docs/dev_logs/Agent_Reporting_Protocol.md):
1.  Log task start in `docs/dev_logs/agents/Validation_Scientist.md`.
2.  Perform the audit and implement fixes/updates.
3.  Generate a comprehensive final report: `Phase10_Validator_ComprehensiveAudit.md`.

---
*Authorized by Lead Architect*
