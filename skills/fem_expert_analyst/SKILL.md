---
name: "fem_expert_analyst"
description: "Perform physical and mathematical correctness audits for Finite Element implementations."
---

# FEM Expert Analyst Skill

This skill enables an agent to act as a high-level reviewer for the `CurveShellFEM` project, focusing on the theoretical validity of the code.

## Knowledge Areas
- **Continuum Mechanics**: Stress/strain measures, objective rates, balance laws.
- **Finite Element Theory**: Variational principles, discretization, locking, stability, Linear and Nonlinear FEM.
- **Numerical Methods**: Newton-Raphson, Arc-Length, Stress Integration (Radial Return).

## Procedures

### 1. Constitutive Verification (Stress Integration)
When a new material model is implemented, follow these steps to verify it:
1. **Consistency of Tangent (ATM)**: 
   - Ensure the `Dep` (Algorithmic Tangent Modulus) is the exact derivative of the `sigma` with respect to `epsilon`.
   - Use a numerical perturbation test if in doubt.
2. **Objectivity**:
   - Verify that the model is invariant under rigid body rotations.
3. **Plane Stress Constraint**:
   - For shell elements, ensure the plane stress condition ($\sigma_{33} = 0$) is strictly satisfied in the iterative loop.

### 2. Element Formulation Audit
1. **Jacobian Positivity**:
   - Check that $det(\mathbf{J}) > 0$ at all integration points.
2. **Locking Check**:
   - Identify if the element is susceptible to shear or membrane locking. 
   - Recommend Selective Reduced Integration (SRI) or Assumed Natural Strain (ANS) if necessary.
3. **Internal Force Continuity**:
   - Ensure the virtual work expression is correctly discretized.
4. **Linear and Nonlinear FEM**:
   - Ensure the virtual work expression is correctly discretized.
   - Distinguish between linear and nonlinear FEM.
   - Know the difference between total Lagrangian and updated Lagrangian formulations.

## Tools and Scripts
- `skills/fem_expert_analyst/scripts/verify_tangent.m`: A MATLAB utility to numerically check the consistency of a material's tangent matrix.
- `skills/fem_expert_analyst/scripts/Nolinear archlength solver/`: A MATLAB utility to solve nonlinear problems using arc-length method.

## Reporting
All audits must conclude with an **Analyst Report** using the `Analyst_Report_Template.md`.
