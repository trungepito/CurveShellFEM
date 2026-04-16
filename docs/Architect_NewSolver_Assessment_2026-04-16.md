# Senior Architect Review — New Nonlinear Solver

Date: 2026-04-16  
Scope reviewed: unified nonlinear pipeline centered on `FEM_Solver_Nonlinear`, strategy-driven increment control, centralized `SolutionState`, and associated support classes.

## Executive Summary

The new solver architecture is a **major step forward** from both maintainability and numerical-governance perspectives. The strongest decisions are: (1) migration toward a single nonlinear entry point, (2) explicit strategy polymorphism for increment/constraint behavior, and (3) append-only state archival that reduces hidden side effects. These choices materially lower long-term defect probability in coupled geometric/material nonlinear workflows.

The main residual risks are concentrated in implementation consistency:

1. **Residual-sign convention mismatch** between Newton loop and line-search can degrade robustness near snap-through and plastic transitions.
2. **Dual assembly paths** (`obj.assembleTangentSystem` vs `Assembler.tangent`) indicate incomplete consolidation and potential divergence in behavior/performance.
3. **Convergence monitor usage is inconsistent** (Newton loop passes physically meaningful `dU`; stage corrector currently passes empty `dU`), weakening energy/displacement norm semantics.
4. **State/history compatibility debt** remains due to broad backward-compatibility shims and mixed legacy fields.

Overall recommendation: proceed with targeted hardening in three waves (correctness, performance, governance), while preserving the current architecture direction.

---

## What Is Strong (Pros)

### 1) Architecture unification around one nonlinear solver core

`FEM_Solver_Nonlinear` now acts as the unified stage-aware nonlinear engine, reducing fragmentation across former solver variants and concentrating control flow in one place. This is the right macro-architecture for future extensions (new constraints, continuation variants, solver diagnostics).【F:src/@FEM_Solver_Nonlinear/FEM_Solver_Nonlinear.m†L1-L23】【F:src/@FEM_Solver_Nonlinear/solve.m†L1-L14】

### 2) Strategy pattern is correctly introduced at the domain seam

Abstract `IncrementalStrategy` and concrete implementations (`RiksStrategy`, `LoadControlStrategy`, `DispControlStrategy`) isolate constraint mathematics from driver orchestration. This sharply improves testability and eliminates brittle string-based branching from the solver hot path.【F:src/@IncrementalStrategy/IncrementalStrategy.m†L1-L33】【F:src/@RiksStrategy/RiksStrategy.m†L1-L17】【F:src/@LoadControlStrategy/LoadControlStrategy.m†L1-L13】【F:src/@DispControlStrategy/DispControlStrategy.m†L1-L18】

### 3) State management boundary is materially improved

`SolutionState` provides append-only archival with explicit stage boundaries, preparing the codebase for deterministic replay and postprocessing decoupling. This is essential for reproducibility and regression certification in nonlinear FEM environments.【F:src/@SolutionState/SolutionState.m†L1-L12】【F:src/@SolutionState/SolutionState.m†L56-L104】

### 4) Side-effect reduction in assembly and Newton loop

`Assembler` is stateless and explicit in inputs/outputs, and `newtonLoop` now avoids commit-on-failure and protects entry-state semantics on divergence. These are high-value reliability upgrades for adaptive stepping and cutback flows.【F:src/@Assembler/Assembler.m†L1-L11】【F:src/@FEM_Solver_Nonlinear/newtonLoop.m†L1-L12】【F:src/@FEM_Solver_Nonlinear/newtonLoop.m†L22-L30】【F:src/@FEM_Solver_Nonlinear/newtonLoop.m†L89-L102】

### 5) Convergence diagnostics are richer than legacy implementations

`ConvergenceMonitor` supports force/energy/displacement criteria plus recommendation hooks (abort/cutback/linesearch), enabling smarter nonlinear control policies than fixed tolerance-only checks.【F:src/@ConvergenceMonitor/ConvergenceMonitor.m†L1-L8】【F:src/@ConvergenceMonitor/ConvergenceMonitor.m†L74-L90】

---

## What Needs Attention (Cons / Risks)

### 1) Residual-sign inconsistency across solver components

`newtonLoop` defines residual as `R = F_int - F_ext`, while `linesearch` evaluates trial residual as `R_trial = F_ext_current - F_int_trial`. This sign inversion can invert directional metrics and acceptance behavior in line-search logic, especially when heuristics depend on dot products and monotonicity tests.【F:src/@FEM_Solver_Nonlinear/newtonLoop.m†L13-L16】【F:src/@FEM_Solver_Nonlinear/newtonLoop.m†L49-L52】【F:src/@FEM_Solver_Nonlinear/linesearch.m†L15-L18】

### 2) Assembly stack is not fully consolidated

`newtonLoop` uses `Assembler.tangent`, while `solveIncrementalStage` uses an internal closure around `obj.assembleTangentSystem` and additional helper assembly calls. This creates two correctness/performance surfaces for nominally the same operation and increases regression risk when one path changes.【F:src/@FEM_Solver_Nonlinear/newtonLoop.m†L46-L47】【F:src/@FEM_Solver_Nonlinear/solveIncrementalStage.m†L39-L46】【F:src/@FEM_Solver_Nonlinear/solveIncrementalStage.m†L126-L137】

### 3) Convergence metric inputs are uneven between loops

In the arc-length corrector, convergence checks pass `[]` for `dU_free`, which undermines displacement/energy norm semantics and can hide poor step quality when force norm alone appears acceptable. This is a latent quality risk under strongly nonlinear response paths.【F:src/@FEM_Solver_Nonlinear/solveIncrementalStage.m†L142-L145】【F:src/@ConvergenceMonitor/ConvergenceMonitor.m†L46-L69】

### 4) Complexity concentration in one large stage driver

`solveIncrementalStage` now combines stage orchestration, adaptive trials, predictor/corrector solve logic, convergence policy actions, L-BFGS history management, archival, and eventing. This improves single-path control, but current method size and responsibility breadth increase maintenance burden and bug-surface density.【F:src/@FEM_Solver_Nonlinear/solveIncrementalStage.m†L1-L19】【F:src/@FEM_Solver_Nonlinear/solveIncrementalStage.m†L79-L178】【F:src/@FEM_Solver_Nonlinear/solveIncrementalStage.m†L237-L296】

### 5) Backward-compatibility shims are still carrying technical debt

The roadmap itself documents unresolved compatibility and mutation-boundary issues (e.g., legacy option aliases, postprocessor interaction boundaries, and historical reconstruction paths). Without closing this debt, new architecture gains can be diluted by legacy code paths.【F:newsolver/curveshell_implementation_roadmap.html†L72-L83】【F:newsolver/curveshell_implementation_roadmap.html†L84-L98】

---

## Enhancement Plan (Senior Architect Recommendation)

## Wave 1 (1–2 weeks): Correctness hardening — must complete first

1. **Unify residual convention end-to-end**
   - Standardize to a single residual definition across Newton, arc-length corrector, and all line-search variants.
   - Add regression checks for sign-sensitive behavior (snap-through acceptance, line-search monotonicity).

2. **Convergence monitor contract tightening**
   - Require non-empty `dU_free` where energy/displacement norms are enabled.
   - Fail-fast or auto-downgrade norm type with explicit warning when required inputs are missing.

3. **Single authoritative tangent/internal-force path**
   - Route both Newton and arc-length through one shared assembly interface.
   - Keep optimized fast paths internal but hidden behind the same contract.

4. **Deterministic failure semantics**
   - Guarantee no trial-history or mutable element state is committed on non-convergence for every strategy branch.

Deliverable: “Numerical Correctness Gate” report covering 3 canonical nonlinear scenarios (limit-point, material yielding, mixed control).

## Wave 2 (2–3 weeks): Performance and scalability

1. **Factorization reuse policy formalization**
   - Explicit rebuild criteria for tangent matrix (iteration count, curvature changes, monitor signals).
   - Telemetry on rebuild frequency and solve-cost breakdown.

2. **L-BFGS governance envelope**
   - Add acceptance criteria quality checks and rollback triggers for quasi-Newton directions.
   - Capture speedup vs robustness tradeoff per benchmark family.

3. **Memory lifecycle strategy for large runs**
   - Complete and validate rolling/disk modes in `SolutionState` with strict replay guarantees.

Deliverable: “Performance Envelope” dashboard (time, memory, convergence robustness).

## Wave 3 (2 weeks): API stabilization and verification governance

1. **Deprecation completion**
   - Remove legacy option aliases and residual legacy branch points after migration window.

2. **Verification gate automation**
   - Promote roadmap verification tasks to mandatory CI gate for nonlinear merges.

3. **Postprocessor boundary lock**
   - Enforce snapshot-only postprocessing access for immutable historical replay.

Deliverable: “Solver vNext Stable API” + CI gate policy.

---

## Prioritized Action Backlog (Top 8)

1. P0: Residual-sign unification + line-search alignment.
2. P0: Convergence monitor input-contract enforcement.
3. P0: Shared assembly contract used by both driver modes.
4. P1: Break `solveIncrementalStage` into composable private units (predict, correct, accept, archive).
5. P1: Introduce deterministic nonlinear replay test harness (same inputs -> same convergence history).
6. P1: Benchmark L-BFGS on/off with guarded activation criteria.
7. P2: Complete memory mode validation (`all`, `rolling`, `disk`).
8. P2: Sunset compatibility shims after migration metrics are met.

---

## Final Assessment

The new solver is **architecturally directionally correct** and substantially better than the legacy fragmented model. The remaining work is not a redesign; it is a controlled hardening and consolidation program. If Wave 1 is executed with discipline, this solver can become a robust long-horizon platform for advanced nonlinear and path-following analysis in CurveShellFEM.
