# Phase 28 Task Brief: DevOps Engineer (Infrastructure)

**Phase**: 28 (Infrastructure, Robustness & Documentation Consolidation)  
**Role**: DevOps & CI/CD Infrastructure  
**Objective**: Establish an automated testing pipeline and explicit path management for CurveShellFEM.

---

## 1. Responsibilities

1. **Deploy CI/CD Pipeline (GitHub Actions)**:
   - Create `.github/workflows/matlab-tests.yml` to run the test suite on every push/pull request.
   - Include: `setup_project.m`, unit tests (`runtests('tests/unit')`), and the complete 19-benchmark suite.
   - Artifact management: Export regression reports and performance metrics.

2. **Explicit Path Management (Phase 26 Fix)**:
   - Refactor test harnesses to use explicit path setup (e.g., `addpath(fullfile(root, 'src'))`) to avoid implicit dependency risks.
   - Ensure the CI/CD environment correctly initializes the MATLAB path.
   - Standardize path management across all project entry points.

3. **Automated Regression Dashboard**:
   - Integrate `benchmark_runner_comprehensive.m` output with the CI/CD pipeline.
   - Generate automated reports showing pass/fail status for all 19 benchmarks.

---

## 2. Deliverables

- `.github/workflows/matlab-tests.yml`: Automated CI/CD workflow.
- Updated `run_all_tests.m` and `setup_project.m` for CI/CD compatibility.
- Standardized path management pattern across the workspace.

---

## 3. Success Criteria

- CI/CD pipeline correctly identifies failures (unit tests and benchmarks).
- Zero "Undefined function" errors in a clean MATLAB session.
- Automated regression report generated for every PR.

---

## 4. Next Step: Brief-Bind

Submit a **BRIEF-BIND statement** in your Phase 28 session log quoting this objective verbatim to confirm understanding.

*Issued by: Lead Architect — 2026-04-02*
