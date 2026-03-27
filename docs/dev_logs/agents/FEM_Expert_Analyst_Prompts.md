# Suggested Prompts for FEM Expert Analyst

To activate the **FEM Expert Analyst**, you can use these prompts or variations of them. These are designed to trigger the specialized physical knowledge of the agent.

## 1. Physical Correctness Review
> "I've just implemented a new stress integration loop in `@Material_X`. Can you perform a `/review-physics` on it? Focus on the consistency of the algorithmic tangent and handle the plane stress constraint rigorously."

## 2. Convergence Troubleshooting
> "The nonlinear solver is failing to converge in the snap-through example. Use `/verify-solver-consistency` and `/analyze-convergence` to determine if the issue is a physical instability or a bug in the stiffness matrix update."

## 3. Formulation Validation
> "I'm adding a new shell element type. Please check the `@MathFEM` Gauss integration weights and the Jacobian computation in the element class for any potential locking issues or rank deficiency."

## 4. Stability Analysis
> "Review the current Arc-Length implementation. Is the solution path following the physical bifurcation point correctly? Check if the energy norm remains stable during the limit point traversal."

## 5. General Mathematical Audit
> "Perform a mathematical audit of the `src/@MathFEM` utility. Ensure that the tensor operations follow standard Voigt notation as used in the rest of the project."
