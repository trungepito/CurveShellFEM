---
description: Run the Arc-Length (Crisfield) benchmark analysis
---

# Arc-Length (Crisfield) Analysis Workflow

This workflow guides you through tracing a nonlinear equilibrium path (including snap-through) using the Arc-Length solver.

1.  **Configure Solver Options**:
    Ensure the `SolverOptions` object has `UseArcLength = true` and an appropriate `ArcLengthRadius`.
    ```matlab
    opts = SolverOptions();
    opts.UseArcLength = true;
    opts.ArcLengthRadius = 0.05; % Adjust based on expected deflection
    opts.MaxArcLength = 2.0;
    ```

2.  **Run Solver**:
    // turbo
    `Sol = FEM_Solver_NL(Model);`
    `Sol.solveArcLength(opts);`

3.  **Monitor Convergence**:
    - If the solver fails with "Imaginary Roots", **reduce** the `ArcLengthRadius`.
    - If it takes too many iterations, the internal adaptive logic will automatically shrink the radius.

4.  **Visualize Results**:
    Use the post-processor to plot the Load-Displacement path.
    // turbo
    `Post = FEM_Postprocessor(Sol);`
    `Post.plotField('Displacement');`
    `Post.animateScenario(plotNodeID, plotDOF);`
