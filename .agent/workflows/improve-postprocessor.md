---
description: Unified Agent Workflow for Overhauling the FEM Postprocessor Architecture
---

# Agent Workflow: Postprocessor Upgrade Pipeline

This workflow governs the systematic overhaul of the `FEM_Postprocessor` to introduce high-performance vectorization, a MATLAB Application GUI, and an industrial VTK ParaView exporter.

**Agent Directives:** Execute these phases strictly sequentially. Do not jump to UI design before the underlying recovery math is accelerated.

## Phase A: Core Vectorization
1. Target: `src/@FEM_Postprocessor/recoverNodalSmooth.m`.
2. **Action**: Remove the `e = 1:nElems` loop. Pre-allocate an array of size `[nNodes, 1]` for values and `[nNodes, 1]` for weights.
3. **Action**: Extract `obj.Solver.U` once. Vectorize the shape function mapping so `accumarray` tallies all Gauss point contributions to the active global nodes simultaneously.
4. **Verification**: Run `BenchmarkSolvers.m` (Linear Cantilever) and use `tic/toc` to assert stress recovery is near-instantaneous.

## Phase B: Interactive UI Application
1. Target: Root directory or `src` - Create `FEM_Postprocessor_App.m`.
2. **Action**: Program a strict class-based `uifigure` Application. 
   - Define a `uiaxes` occupying 80% screen width.
   - Define a 20% control panel containing `uidropdown` for field selection, `uicheckbox` for deformed shape, and `uislider` for Step scrubbing.
3. **Action**: Bind the `uislider` to `obj.Solver.U_Hist`. When scrubbing, update `Axes.Children.CData` and `Vertices` directly instead of calling `cla()`.
4. **Verification**: Load the solved Arch model into the App and assert slider dragging smoothly updates the 3D surface.

## Phase C: High-Fidelity VTK Export
1. Target: `src/@FEM_Postprocessor/exportVTK.m`.
2. **Action**: Create an XML UnstructuredGrid (`.vtu`) writer. 
   - Write `<Points>` block for nodal coordinates.
   - Write `<Cells>` block mapping the 8-node patches to VTK Cell Type 23 (Quadratic Quadrilateral).
   - Write `<PointData>` block mapping Displacements and Stresses.
3. **Action**: Add an Export button to the App control panel triggering this method.
4. **Verification**: Verify the `.vtu` file imports correctly into an open-source ParaView instance without format errors.
