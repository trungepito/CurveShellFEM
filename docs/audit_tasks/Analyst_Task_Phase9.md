# Analyst Task: Phase 9 Locking Mitigation Theory

**Goal**: Provide the theoretical basis for ANS and EAS in the new `Curve8Element_ANS_EAS`.

## Specific Questions
1. **ANS Sampling**: For our 8-node serendipity shell, what are the optimal sampling points for the transverse shear strains ($\gamma_{\xi z}, \gamma_{\eta z}$)? Recommend the interpolation scheme (e.g. Bathe-Dvorkin).
2. **EAS Basis**: Since we use a 5-DOF mixed basis (expanded to 6-DOF with drilling stabilization), how many EAS parameters ($\alpha$) should we use to mitigate membrane locking? Recommend the interpolation matrix $M(\xi, \eta)$.
3. **Consistency**: Ensure the EAS enhancement satisfies the Patch Test and does not introduce spurious zero-energy modes.

## Required Output
Update `docs/dev_logs/agents/FEM_Expert_Analyst.md` with your recommendations and technical rationale.
