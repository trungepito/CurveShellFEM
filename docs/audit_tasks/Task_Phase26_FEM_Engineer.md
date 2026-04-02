# Task Brief — Phase 26: FEM_Solver_Nonlinear Defect Investigation & Fix

**Phase**: 26
**Status**: GATE 0 — ISSUED
**Date**: 2026-03-31
**Issued by**: Lead Architect
**Authority**: v4.1 Agent System, Escalated Defect Response

---

## Critical Objective

**FEM_Solver_Nonlinear contains a significant defect that blocks solver testing and physics work. Your responsibility as FEM Engineer is to:**

1. Identify the root cause of the solver defect
2. Diagnose whether the issue is in:
   - `newtonLoop.m` (convergence logic, residual calculation, or iteration control)
   - `assembleTangentSystem.m` (matrix assembly or force calculation)
   - `FEM_Solver_Nonlinear.m` (class properties or method delegation)
   - Element interface (computeGlobalMatrix6DOF signature or TrialHist generation)
   - Preprocessor initialization affecting solver (FEM_Preprocessor_v2 path/construction)
3. Fix the defect and verify convergence
4. Document the root cause and solution in session log with mathematical derivation of the fix

**Acceptance**: Solver must pass all unit tests in `tests/unit/TestSolvers.m` with 100% pass rate.

---

## Scope (In-Scope)

- Investigation of FEM_Solver_Nonlinear code (newtonLoop, assembly, history management)
- Root-cause diagnosis of solver failure
- Implementation of fix in `src/@FEM_Solver_Nonlinear/` or affected parent class
- Unit test verification (TestSolvers.m must pass)
- Mathematical documentation of convergence behavior (if any changes to tolerances or iteration strategy)

---

## Scope (Out-of-Scope)

- Benchmark execution (to be done by Verification Engineer in Gate 1)
- Full physics derivation report (not needed for defect fix; only mathematical notes on changes)
- Refactor of solver architecture (fix only; no redesign unless defect makes it mandatory)

---

## Known Failure Indicators

The following have been observed:

1. **Test Execution Failure**: `tests/unit/TestSolvers.m` fails to initialize model in setup phase
   - Error: `Undefined function 'FEM_Preprocessor_v2'`
   - This blocks all solver tests from running

2. **Potential Issues in newtonLoop.m**:
   - Convergence tolerance application
   - Residual calculation (R = F_int - F_external)
   - Reaction force calculation (F_int(fixed_dofs) — sign convention uncertain)
   - Trial-commit history management across iterations

3. **Potential Issues in assembleTangentSystem.m**:
   - Element method call signature (computeGlobalMatrix6DOF)
   - Triplet sparse assembly correctness
   - TrialHist generation and return semantics

---

## Deliverables

| Deliverable | Status | Verification |
|:---|:---|:---|
| Session log (start before any fixes) | — | Date opened, objective quoted, mathematics section |
| Root-cause diagnosis document | — | Section in session log describing defect location and cause |
| Fixed code (src/@FEM_Solver_* or src/@FEM_Solver\*) | — | Code review by Lead Architect |
| Unit test pass log | — | `tests/unit/TestSolvers.m` —result: PASSED (all 4 tests) |

---

## Acceptance Criteria

**All of the following must be true before Gate 1 verification:**

- [ ] `tests/unit/TestSolvers.m` runs completely (no setup errors)
- [ ] All 4 test cases pass (testLinearSolver, testNonLinearSolver, testAdaptiveSolver, testArcLengthConstraints)
- [ ] Session log created with Date opened before any code changes
- [ ] Root-cause analysis documented in session log
- [ ] Mathematical derivation section explains convergence fix (if any iterative changes made)
- [ ] No regression in existing benchmarks (VE to verify in Gate 1)

---

## Gateway Expectations

**Gate 0** (this brief): Authority granted to proceed. FEM Engineer to open session log and begin investigation.

**Gate 1** (VE hand-off): Verification Engineer confirms zero test regressions and checks benchmarks still pass.

**Gate 2** (Architect sign-off): Approve continuation to next physics work once defect is resolved.

---

## Constraints & Assumptions

- **Backward compatibility**: Fix must not break existing benchmark results
- **No redesign**: This is defect fix, not architecture refactor
- **Non-parallel**: Only one effort team per solver subsystem
- **Timeline**: Target completion 2026-04-15 (Phase 25 retroactive was expedited; Phase 26 is priority defect)

---

*Issued by: Lead Architect — v4.1 CurveShellFEM*
*Effective immediately upon user confirmation*

---

**NEXT STEP**: FEM Engineer to confirm receipt, then proceed to open Phase 26 session log and begin root-cause diagnosis.
