# Plate combined loading analysis

## Problem definition

A simply supported square plate (1.0 m × 1.0 m, t = 10 mm, steel) is loaded by two simultaneous actions:

| Load | Direction | Type |
|---|---|---|
| Uniform transverse pressure q = 10 kPa | Z (out-of-plane) | Distributed, applied to all elements |
| Membrane displacement u_x = 5 mm | X (in-plane) | Prescribed displacement at X = Lx edge |

The combination puts the plate well into the geometric nonlinear regime: the deflection-to-thickness ratio w/t exceeds 1 at full load, meaning membrane stretching provides a significant stiffening effect that linear theory misses.

## Boundary conditions

```
Simply supported on all four edges:
  w  = 0   (DOF 3)       — all edge nodes
  Rx = 0   (DOF 4)       — edges parallel to X (Y=0, Y=Ly)
  Ry = 0   (DOF 5)       — edges parallel to Y (X=0, X=Lx)

Membrane:
  Ux = 0   (DOF 1)       — X=0 edge  (fixed reference)
  Uy = 0   (DOF 2)       — Y=0 edge  (prevents rigid-body Y motion)
  Ux = u_x (DOF 1)       — X=Lx edge (prescribed, ramped in Stage 1)
```

Note: the simply supported condition allows free in-plane sliding at the edges — only w and the bending rotation about the edge tangent are constrained. This matches classical Navier plate theory.

## Solver stages

### Arc-length (Riks) solver

| Stage | Content | Constraint |
|---|---|---|
| 1 | Ramp membrane displacement Ux from 0 to 5 mm | DispControl (single large step) |
| 2 | Ramp transverse pressure from 0 to full q | Riks arc-length |

Stage 2 uses the Riks constraint so the solver can trace the nonlinear pressure–deflection path automatically, adapting the arc-length radius when convergence is easy or difficult.

### Adaptive GNI solver

| Stage | Content |
|---|---|
| 1 | Membrane displacement ramp (bisection-adaptive time stepping) |
| 2 | Pressure ramp (proportional, adaptive time stepping) |

The GNI solver uses `FEM_Solver_Adaptive` with `Curve8Element_GNI` (geometric nonlinear incremental element). It bisects the pseudo-time step when Newton fails to converge.

## Expected physics

The Navier linear solution for a simply supported plate under uniform pressure q is:

```
w_centre = 0.00406 × q × a⁴ / D
         = 0.00406 × 10000 × 1.0⁴ / (200e9 × 0.001⁰ / 12 / 0.91)
         ≈ 2.2 mm   (linear, no membrane prestress)
```

With the applied membrane strain ε_x = u_x / Lx = 0.5%, the tensile membrane forces stiffen the plate in both analyses. The nonlinear w/t deflection ratio at full load should come out between 1 and 3 — confirming the large-deflection regime — and the nonlinear result should be noticeably stiffer than the linear Navier value.

## Running the script

```matlab
setup_project;              % adds all src/ paths
plate_combined_analysis;    % runs both analyses and produces all figures
```

The script produces five figures:

1. Final deformed shape (displacement magnitude, exaggerated ×20)
2. Von Mises stress map on the top surface
3. Load–displacement curve: λ vs centre deflection w
4. Membrane–bending interaction: u_x vs w at the plate centre
5. Arc-length adaptive radius history

## Key parameters to vary

| Parameter | Variable | Default |
|---|---|---|
| Mesh density | `nEl` | 6 |
| Pressure | `q_pressure` | 10 kPa |
| Membrane displacement | `u_x_prescribed` | 5 mm |
| Arc-length radius | `ArcLengthRadius` | 0.04 |
| Max iterations | `opts_arc.MaxIterations` | 25 |
