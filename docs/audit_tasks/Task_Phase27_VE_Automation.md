# Phase 27 | Task Brief: Verification Engineer (Automation & Regression Harness)
**Date**: 2026-03-31  
**Phase**: 27 (Comprehensive Benchmark Suite)  
**Role**: Verification Engineer  
**Gate**: 0 → 0.5 (Awaiting Brief-Bind)

---

## 1. Objective

"Automate comprehensive benchmark execution and validation. Your responsibility is to: (1) Build centralized benchmark runner harness executing all 19 benchmarks, (2) Generate baseline snapshots for regression testing, (3) Establish automated acceptance criteria checking, (4) Create performance profiling (iteration counts, convergence rates), (5) Produce comprehensive verification report with pass/fail status and metrics."

---

## 2. Your Deliverables

### Deliverable 1: Benchmark Runner Harness
**File**: `benchmark_runner_comprehensive.m`

**Functionality**:
1. **Discovers all benchmarks** in `examples/benchmark_*.m`
2. **Executes each benchmark** in isolated environment (clear workspace, addpath setup)
3. **Captures outputs**: console output, warnings, errors
4. **Records timing**: elapsed time per benchmark
5. **Detects completion/failure**: categorizes success vs. errors
6. **Generates summary**: pass/fail status table

**Interface**:
```matlab
% Usage:
results = benchmark_runner_comprehensive();

% Output structure:
% results.benchmarks = [N×1] table with columns:
%   - Name (benchmark filename)
%   - Status (PASS/FAIL/ERROR)
%   - ElapsedTime (seconds)
%   - IterationCount (from solver output)
%   - ConvergenceRate (iterations per step, or NaN)
%   - ErrorMessage (if failed)
```

**Implementation Requirements**:
- Robust error handling (try-catch for each benchmark)
- Prevents one failure from stopping suite
- Captures both stdout and stderr
- Records detailed diagnostic info
- Generates CSV export for analysis

---

### Deliverable 2: Baseline Snapshot Generation
**File**: `benchmark_baseline_snapshot.m`

**Functionality**:
1. Run all benchmarks
2. Extract key outputs from each:
   - Final displacements (solution vector U)
   - Final stresses (element-wise stress tensor)
   - Load-displacement curve (F vs. δ)
   - Convergence history (iterations per step)
   - Iteration counts (total, average per step)
3. Save baselines to `.mat` file: `benchmark_baseline_phase27.mat`

**Structure**:
```
baseline.
  ├─ snapthrough_arclength
  │   ├─ U_final (displacement vector)
  │   ├─ stress_final (stress field)
  │   ├─ load_disp (N×2: [step, λ])
  │   ├─ iter_history ([steps with iter counts])
  │   ├─ timestamp (generation date)
  │   └─ solver_options (tolerances, max_iter, etc.)
  ├─ gmnia_cylindrical_panel
  │   └─ (same structure)
  ├─ ...
  └─ (all 19 benchmarks)
```

**Usage**: Baselines used in future phases for regression testing (Phase 28+)

---

### Deliverable 3: Automated Acceptance Criteria Checking
**File**: `benchmark_validator.m`

**Functionality**:
1. Load acceptance criteria from configuration file
2. For each benchmark, extract results
3. Compare against criteria: displacement error, convergence rate, iteration count
4. Assign PASS/FAIL/WARNING status
5. Generate detailed report with violations highlighted

**Acceptance Criteria Configuration**:
```matlab
criteria.cantilever_linear.
  max_displacement_error_pct = 0.1;  % vs. analytical
  max_convergence_iterations = 5;
  expected_iterations_per_step = 1;

criteria.snapthrough_arclength.
  expected_final_lambda = 11.35;
  lambda_tolerance_pct = 1.0;
  expected_steps = 50;
  max_steps_deviation = 5;
  max_avg_iterations_per_step = 2;
```

**Report Output**:
```
╔═══════════════════════════════════════════╗
║      ACCEPTANCE CRITERIA REPORT           ║
╠═══════════════════════════════════════════╣
║ Benchmark        │ Status  │ Details     ║
├──────────────────┼─────────┼─────────────┤
║ cantilever_lin   │ ✓ PASS  │ Error: 0.08%║
║ snapthrough_al   │ ✓ PASS  │ λ: 11.35   ║
║ gmnia_panel      │ ⚠ WARN  │ Iter: 2.3 → │
║ plastic_cant     │ ✗ FAIL  │ Conv. fail  ║
╚═══════════════════════════════════════════╝
```

---

### Deliverable 4: Performance Profiling
**File**: `benchmark_profiler.m`

**Metrics Captured**:

1. **Convergence Efficiency**:
   - Iterations per step (average, min, max)
   - Total iterations for whole analysis
   - Residual norm decay rate

2. **Solver Timing**:
   - Assembly time per step
   - Linear solver time per step
   - Nonlinear iteration overhead
   - Total elapsed time

3. **Problem Scale**:
   - Number of DOFs
   - Number of elements
   - Matrix sparsity

**Output Format**:
```
Performance Profile: snapthrough_arclength
  Problem Size: 2208 DOFs, 367 elements
  Total Time: 23.4 seconds
  Assembly avg: 0.42 s/step
  Solver avg: 0.02 s/step
  Nonlinear iter avg: 1.0 iter/step
  Convergence: Quadratic (Newton)
```

---

### Deliverable 5: Comprehensive Verification Report
**File**: `Phase27_VE_Verification_Report.md`

**Report Contents**:

**Section 1: Executive Summary**
- Total benchmarks: 19
- Passed: X / 19
- Failed: Y / 19
- Overall status: PASS/FAIL

**Section 2: Benchmark-by-Benchmark Results**
```
| Benchmark | Solver | Status | Time | Iters | Notes |
|-----------|--------|--------|------|-------|-------|
| ... | ... | ... | ... | ... | ... |
```

**Section 3: Solver Compatibility Matrix**
```
|            | Linear | Nonlin | Adaptive | ArcLen |
|------------|--------|--------|----------|--------|
| Static     | ✓      | ✓      | ✓        | ✓      |
| Dynamic    | -      | ✓      | ✓        | ✓      |
| Eigenvalue | ✓      | N/A    | N/A      | N/A    |
| Plasticity | N/A    | ✓      | ✓        | ✓      |
```

**Section 4: Performance Metrics Summary**
- Average iterations per step (by solver type)
- Timing breakdown (assembly vs. solve)
- Convergence efficiency (solver vs. problem type)

**Section 5: Regression Summary**
- Baseline snapshots generated: YES
- Future regression test ready: YES
- Baseline path: `benchmark_baseline_phase27.mat`

**Section 6: Recommendations**
- Any benchmarks needing tuning?
- Suggested tolerances for Phase 28+?
- Performance optimization opportunities?

---

## 3. Automated Testing Workflow

### Workflow Summary

1. **Trigger**: Run `benchmark_runner_comprehensive()` (or nightly automation)  
2. **Execution**: Each benchmark runs in isolated environment
3. **Capture**: Outputs, timing, convergence data recorded
4. **Validation**: Results checked against acceptance criteria  
5. **Profiling**: Performance metrics computed
6. **Reporting**: Summary report generated
7. **Archival**: Baseline snapshots saved for regression
8. **Notification**: Results reported to Lead Architect

### Error Handling

- Benchmark fails → logged as ERROR, suite continues
- Solver diverges → logged as FAIL, not ERROR
- Output capture error → logged separately
- Ensures robustness: one bad benchmark doesn't crash test suite

---

## 4. Success Criteria (Gate 0.5 Brief-Bind)

**You confirm that you can deliver**:
- ✓ Benchmark runner harness (all 19 benchmarks) by deadline
- ✓ Baseline snapshot generation and loading by deadline
- ✓ Automated acceptance criteria validator by deadline
- ✓ Performance profiling system in place by deadline
- ✓ Comprehensive verification report ready by deadline
- ✓ All deliverables integrated and tested by deadline

---

## 5. BRIEF-BIND STATEMENT (Required before Gate 0.5)

```
[Your Name], acting as Verification Engineer, confirm full responsibility for: 
(1) centralized benchmark runner harness, (2) baseline snapshot generation system, 
(3) automated acceptance criteria checking, (4) performance profiling utilities, 
(5) comprehensive verification report generation.

I confirm current availability and expected delivery: [date].
```

---

## 6. Questions for Clarification

- Should runner harness attempt to run benchmarks in parallel or sequentially?
- How should baseline snapshots handle potential MATLAB version differences?
- What tolerance should regression checking use (exact match vs. %error)?
- Should performance profiling include memory usage profiling?

