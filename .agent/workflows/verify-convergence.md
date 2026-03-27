---
description: "Use when verifying numerical convergence rates (L2, energy norms) against theoretical expectations."
---

# Verify Convergence Workflow (Validation Scientist)

## Objective
Scientifically prove that the discretization scheme achieves the expected rate of convergence as the mesh is refined.

## Steps

1. **Benchmark Selection**:
    - Choose a problem with a known analytical solution (e.g., Timoshenko beam, Scordelis-Lo roof).

2. **Mesh Refinement Series**:
    - Define a series of nested meshes (e.g., $h, h/2, h/4, h/8$).
    - Run the simulation for each mesh level.

3. **Error Computation**:
    - Compute the relative error in $L_2$ norm (displacement) or $H_1$ norm (energy).
    - $e = \frac{||u_{fem} - u_{analytical}||}{||u_{analytical}||}$.

4. **Rate Calculation**:
    - Plot $log(error)$ vs $log(h)$.
    - Calculate the slope (rate of convergence). 
    - For quadratic elements, expected rate is $O(h^3)$ for $L_2$ and $O(h^2)$ for energy.

5. **Reporting**:
    - Document the convergence plot in the **Analyst Report**.

## Verification Checklist
- [ ] Analytical solution is verified from literature.
- [ ] Error norms are computed correctly.
- [ ] Convergence plots show a stable slope.
- [ ] Stagnation (round-off) or locking points are identified.
