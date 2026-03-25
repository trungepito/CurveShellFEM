# CurveShellFEM: Master Technical & User Guide

## 1. Overview
**CurveShellFEM** is a high-fidelity MATLAB finite element framework specialized for the analysis of curved shell structures. It features an 8-node serendipity element formulation, advanced nonlinear solvers (Arc-Length and Displacement Control), and a professional-grade post-processing dashboard.

---

## 2. Geometric Modeling & Preprocessing
The `FEM_Preprocessor_v2` class is the central hub for model definition.

### Geometry Creation
- `addKeypoint(x, y, z)`: Define reference points.
- `addLine(p1, p2, 'straight' | 'arc')`: Create boundaries between keypoints.
- `addPatch(l1, l2, l3, l4)`: Define a surface bounded by four lines.
- `createExtrusion(profileNodes, profileSegs, direction, length, density)`: Generate 3D shells by extruding a 2D profile.

### Selection (The "Picker")
- `selectNodesByBox(xmin, xmax, ymin, ymax, zmin, zmax)`: Select node IDs in a 3D box. Useful for BCs.
- `selectNodesOnPlane(dim, val, tol)`: Select nodes on a plane (1=X, 2=Y, 3=Z).

### Meshing
- `meshAllPatches(Nu, Nv)`: Generates an **8-node serendipity mesh** across all defined patches.
- `fuseNodes(tol)`: Merges coincidence nodes at patch boundaries.
- `computeNormals()`: Automatically calculates nodal normals (REQUIRED for shells).

### Physics & BCs
- `addBC(nodes, dofs, value)`: Apply constraints (1=Ux, 2=Uy, 3=Uz, 4=Rx, 5=Ry, 6=Rz).
- `addNodalLoad(nodes, dof, value)`: Apply concentrated forces/moments.
- `addPressureLoad(elements, magnitude)`: Apply surface pressure normal to the shell.

---

## 3. Element Formulation: `Curve8Element`
The project uses a specialized **8-node serendipity shell**.

### Kinematics
- **40 DOFs internally**: 5 DOFs per node ($u, v, w, \alpha, \beta$).
- **6 DOFs per node externally**: The solver maps these to 6 global DOFs ($u, v, w, \theta_x, \theta_y, \theta_z$) to allow intersection with other element types.
- **Mixed Basis**: Utilizes a mixed-basis transformation to avoid shear locking.

### Key Internal Methods
- `computeGlobalMatrix6DOF()`: Returns the $48 \times 48$ stiffness matrix.
- `computeTangentStiffnessAndForce()`: Used in nonlinear analysis to return KT and Internal Force.

---

## 4. Solver Engines
CurveShellFEM includes three primary solvers:

### Linear Static Solver (`FEM_Solver`)
- `solveStatic()`: Solves $K \cdot U = F$.

### Buckling Solver (`FEM_Solver`)
- `solveBuckling(numModes)`: Solves the generalized eigenvalue problem $(K + \lambda K_g) \Phi = 0$.
- Returns critical load factors and mode shapes.

### Nonlinear Solver (`FEM_Solver_NL`)
- **Arc-Length (Crisfield)**: `solveArcLength(initialStep, maxStep, targetLoad)`.
- **Displacement Control**: `solveDisplacementControl(node, dof, target, steps)`.
- **Newton-Raphson**: The core iterative engine.

---

## 5. Post-Processing & The Dashboard
The post-processor is optimized for accuracy and speed.

### Superconvergent Recovery (SPR)
Instead of raw nodal stresses, the framework uses **Gauss-point extrapolation**:
1. Sample stresses at the 4 Superconvergent points.
2. Extrapolate to the 8 nodes.
3. Smooth results across boundaries.

### The Enterprise Dashboard
Launch with `FEM_Postprocessor_App(Post)`.
- **Mode Switching**: Automatically detects Static, Buckling, or Nonlinear history.
- **Layers**: Toggle Top, Mid, and Bottom fibers.
- **Themes**: Switch to **"Light"** or **"Dark"**.
- **Performance**: Fully vectorized recovery engine (up to 50x speedup).

---

## 6. Developer Reference: Internal Data Structures

### File Structure & Organization
- `src/@FEM_Preprocessor_v2`: Geometric setup.
- `src/@Curve8Element`: Elastic math engine.
- `src/@FEM_Solver_NL`: Non-linear strategies.
- `src/@FEM_Postprocessor`: Vectorized recovery.
- `tests/unit`: Automated math verification.

### Verification Examples
- **Snap-through**: `examples/snapthrough.m` (Nonlinear validation).
- **Stress Consistency**: `tests/unit/TestPostprocessor.m` (Recovery validation).
- **Solver Benchmarks**: `tests/benchmarks/BenchmarkSolvers.m` (Performance validation).

---

---

## 9. Material Nonlinearity (Elastoplasticity)
CurveShellFEM supports J2 Plasticity (Von Mises) with isotropic hardening.

### Configuration
1. **Enable Plasticity**:
   ```matlab
   Pre.setMaterialPlastic(sigY, H_mod);
   ```
2. **History Variables**: Each element tracks history at 20 integration points (2x2 Gauss x 5 Simpson).

### Visualization
Extensive plasticity visualization options are available in the post-processor:
- `Post.plotField('PlasticStrain', opts)`: Visualize equivalent plastic strain.
- `Post.plotField('PlasticFront')`: Map the percentage of yielded thickness (0-100%).
- **Layer Control**: Evaluate plasticity at `Top`, `Mid`, or `Bot` fibers.

### Verification Benchmarks
- **Uniaxial Tension**: `examples/test_plasticity_uniaxial.m`.
- **Plastic Snap-through**: `examples/benchmark_plastic_snapthrough.m`.

---

## 10. Performance Tips
Run all tests via:
```matlab
runtests('tests/unit')
```
