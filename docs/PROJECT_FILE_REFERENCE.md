# CurveShellFEM: Project File Reference & Documentation Standard

This document provides a comprehensive map of the Every file in the CurveShellFEM codebase, organized by module.

---

## 🟢 1. The Preprocessor Engine (`@FEM_Preprocessor_v2`)
The entry point for all model data.
- **`FEM_Preprocessor_v2.m`**: Main class definition. Manages `Nodes`, `Elements`, and `BCs`.
- **`addBC.m`**: Standardizes constraint application into a table format.
- **`addNodalLoad.m`**: Maps local loads to global indices.
- **`meshAllPatches.m` / `meshQuadPatch.m`**: The core 8-node serendipity meshing engine.
- **`selectNodesByBox.m`**: A vital utility for selecting boundary nodes based on their 3D coordinates.
- **`fuseNodes.m`**: Crucial for ensuring C0 continuity between independent patches.

## 🔵 2. The Finite Element Library (`@Curve8Element` family)
The mathematical heart of the system.
- **`Curve8Element.m`**: Master class. Handles constitutive math and coordinate transformations.
- **`@Curve8Element_Plastic/Curve8Element_Plastic.m`**: Extends base for J2 plasticity with history variables.
- **`@Curve8Element_GNI/Curve8Element_GNI.m`**: Extends base for Geometric Nonlinear Incremental (GNI) analysis.
- **`fmisoq8.m`**: Defines shape functions ($N$) and their derivatives for 8-node quads.
- **`computeGlobalMatrix6DOF.m`**: Assembles the element stiffness into the global $48 \times 48$ frame.
- **`calculateKinematics.m`**: Computes Jacobians ($J$), local frames ($\theta$), and normals.
- **`getConstitutiveMatrix.m`**: Defines the $D$ matrix for shell bending and membrane behavior.
- **`computestresses.m`**: Calculates centroidal stresses for the solver.

## 🔴 3. The Solver Suite (`@FEM_Solver` family)
Computational strategies for different physics.
- **`FEM_Solver.m`**: The linear base class. Implements `assembleK` and `solveStatic`.
- **`@FEM_Solver_NL/solveDisplacementControl.m`**: Newton-Raphson implementation for stable post-peak analysis.
- **`@FEM_Solver_ArcLength/FEM_Solver_ArcLength.m`**: Adaptive arc-length solver with modular constraints (Riks, LoadControl, DispControl). Inherits from `@FEM_Solver_Adaptive` for event-driven stage solving.
- **`assembleTangentSystem.m`**: Periodic assembly of $K_T$ and $F_{internal}$ for nonlinear loops.

## 🟡 4. The Post-Processor (`@FEM_Postprocessor`)
Visualization and data recovery.
- **`FEM_Postprocessor.m`**: Class manager for results extraction.
- **`recoverNodalSmooth.m`**: **(Vectorized)** Superconvergent stress recovery engine.
- **`FEM_Postprocessor_App.m`**: The professional dashboard GUI.
- **`plotReactionDispCurve.m`**: Generates high-fidelity Force-Displacement plots for nonlinear history.

---

## 📖 5. Proposed Documentation Standard
To help future developers, every new file should follow this **MATLAB Header Standard**:

```matlab
function [out1, out2] = myFunction(arg1, arg2)
% MYFUNCTION - Summary of what the function does in one line.
%
% Syntax:
%   [out1, out2] = myFunction(arg1, arg2)
%
% Inputs:
%   arg1 - Description of input 1 [Type, Dimensions]
%   arg2 - Description of input 2 [Type, Dimensions]
%
% Outputs:
%   out1 - Description of result 1
%   out2 - Description of result 2
%
% Example:
%   [val] = myFunction(10, 'mesh')
%
% See also: RELATED_FUNC_A, RELATED_FUNC_B
%
% Developer Note: [Internal implementation details here]
```

---

## 🛠 6. Maintenance Tasks
- **`setup_project.m`**: Always run this first. It manages the `path` and element caching.
- **`BenchmarkSolvers.m`**: Use this to verify that changes don't degrade the solver's performance.
