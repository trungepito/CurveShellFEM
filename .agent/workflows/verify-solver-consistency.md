---
description: "Use when verifying global solver behavior (equilibrium, convergence rates) against theoretical expectations."
applyTo: "src/@FEM_Solver*"
---

# Verify Solver Consistency Workflow (FEM Expert Analyst)

## Objective
Ensure the global solver (NL, Arc-Length, Adaptive) maintains physical equilibrium and exhibits theoretically predicted convergence rates.

## Steps

1. **Equilibrium Check**:
    - Verify that the residual norm `||R||` reflects true force imbalance. 
    - Check if reactions at boundaries sum up correctly (static equilibrium).

2. **Convergence Rate Analysis**:
    - For Newton-Raphson: Quadratic convergence should be visible near the solution.
    - If linear or stagnation occurs: Identify if it is due to a non-smooth tangent (material) or poor conditioning.

3. **External vs Internal Work**:
    - Track external work $W_{ext}$ and internal energy $U_{int}$ increment.
    - Verify energy balance in complex load paths (e.g., snap-through).

4. **Conditioning Profile**:
    - Evaluate the conditioning of the global stiffness matrix (K_global).
    - Identify potential near-singularities (instabilities).

## Verification Checklist
- [ ] Quadratic convergence recorded for elastic cases.
- [ ] Global equilibrium verified (R_total < tol).
- [ ] Energy balance (Internal vs External work) confirmed.
- [ ] Solver-specific events (e.g., arc-length limit points) correctly handled physically.
- [ ] Report generated using `Analyst_Report_Template.md`.
