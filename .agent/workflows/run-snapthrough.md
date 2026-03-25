---
description: Run the Snap-through benchmark analysis
---

# Benchmark: Snap-through Analysis

Execute the displacement-controlled snap-through analysis of a shallow curved panel.

## Steps

1. **Setup Environment**
   Run `setup_project.m` to ensure all paths are configured.
   // turbo
   `matlab -batch "setup_project"`

2. **Execute Analysis**
   Run the `snapthrough.m` example script.
   // turbo
   `matlab -batch "snapthrough"`

3. **Verify Convergence**
   Check the command line output for convergence at each of the 100 steps.
   The analysis should navigate the snap-point using the bisection logic if needed.

4. **Review Results**
   The script produces a Reaction vs. Displacement curve and an animation of the snap-through event.
