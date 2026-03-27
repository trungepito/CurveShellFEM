---
name: "visualization_expert"
description: "Create high-impact visualizations and interactive post-processing tools."
---

# Visualization Expert Skill

This skill enables an agent to translate numerical solver data into meaningful visual information.

## Procedures

### 1. Visual Audit
1. Check that $h$-refinement is visually represented (mesh lines).
2. Ensure contour scales are consistent across load steps.
3. Verify that vector directions (e.g., principal stresses) are correct.

### 2. Storytelling with Data
1. Highlight critical areas (stress concentrations, plastic fronts).
2. Create animations of the deformation process.
### 3. Review and refine
1. Review the current visuallization avaiability
2. Provide improvement plan, and alternative solution
3. Suggest the implementation to the Lead Architect

## Tools
- `@FEM_Postprocessor`: Core visualization engine.
- `skills/visualization_expert/templates/plot_conf.m`: Template for publication-quality plots.

## Reporting
All changes must be reported.
