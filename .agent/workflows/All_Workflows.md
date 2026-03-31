# Workflow Catalog (v3.0)

Each workflow has: trigger phrase, owning agent, steps, and a verification checklist.
Workflows are invoked by the Lead Architect unless stated otherwise.

---

## WF-01 — manage-project

**Trigger**: "new phase | plan phase | Phase N | decompose tasks"
**Owner**: Lead Architect
**Output**: Two task briefs in `docs/audit_tasks/`, updated roadmap

### Steps

1. Define the phase:
   - Phase number (sequential, no reuse)
   - Primary goal in one sentence
   - Dependencies on prior phases
   - Success criterion — what does "done" look like numerically?

2. Write the FEM Engineer task brief (`Task_Phase{N}_FEM_Engineer.md`) using Template 1:
   - Objectives (bullet list)
   - Whether a formal FEM Report is required (yes for new element/material/constraint, no for refactors)
   - Required output file names

3. Write the Verification Engineer task brief (`Task_Phase{N}_Verification_Engineer.md`) using Template 1:
   - Specific benchmark targets with numeric pass criteria
   - Data integrity checks required
   - Post-processing outputs required

4. Update `docs/PROJECT_ROADMAP.md`: add phase with `[ ]` checkboxes.
5. Update `docs/PROJECT_PLAN_REFACTORED.md`: add phase with `Status: PLANNED`.
6. Ask user to confirm before execution begins.
7. Issue Gate 0: announce both briefs to the respective agents.

### Checklist
- [ ] Both task briefs written with explicit acceptance criteria
- [ ] Roadmap updated
- [ ] User confirmed plan
- [ ] Gate 0 issued

---

## WF-02 — add-element-type

**Trigger**: "new element | Curve8Element_* | element formulation"
**Owner**: FEM Engineer (primary), Verification Engineer (verification)
**Output**: New `@ClassName/` in `src/`, tests in `tests/unit/`, FEM Report, Verification Report

### Steps

**FEM Engineer phase:**

1. Read SK-01 (Shell Element Formulation) before writing any code.
2. Write the physics derivation record first (section in session log or separate FEM Report):
   - Integration scheme (in-plane Gauss points, through-thickness layers)
   - B-matrix changes vs. base element
   - EAS/ANS parameters if applicable
   - Expected zero-energy mode count
   - Patch test prediction
3. Create `src/@Curve8Element_{Name}/` inheriting from `Curve8Element`. Override only differing methods.
4. Add dispatch in `FEM_Solver.buildElementCache` — use `isfield(mat, 'ElementType')` check.
5. Write `tests/unit/TestCurve8Element_{Name}.m` covering:
   - Symmetry: `max(abs(Ke - Ke')) < 1e-13 * max(abs(Ke(:)))`
   - Zero-energy mode count matches derivation prediction
   - Patch test: uniform strain → correct strain energy
   - Curved element: stiffness trace ratio vs. baseline < 1.0
6. Run all unit tests. Confirm pass.
7. Notify Architect → Gate 1.

**Verification Engineer phase (after Gate 1):**

8. Run `test_element_{name}.m` — confirm all assertions pass.
9. Run Scordelis-Lo with `mat.ElementType = '{Name}'` — confirm < 1% vs. baseline.
10. Check that existing element types still produce identical results (no regression in `buildElementCache`).
11. Write Verification Report. Notify Architect → Gate 2.

### Checklist
- [ ] Physics derivation written before coding
- [ ] Inherits correctly; only differing methods overridden
- [ ] `buildElementCache` dispatch correct and backward-compatible
- [ ] All four unit test assertions pass
- [ ] Regression: existing element types unaffected
- [ ] Both reports filed

---

## WF-03 — debug-convergence

**Trigger**: "convergence failure | divergence | solver fails | residual grows | imaginary roots"
**Owner**: Verification Engineer (diagnosis), FEM Engineer (fix)
**Output**: Fixed `src/`, updated unit test, session log entry

### Steps

1. **Reproduce** (VE): isolate to minimal case — fewest elements, simplest load, shortest arc-length path.

2. **Classify** (VE): use SK-07 table. Common patterns:

| Symptom | Likely cause | Action |
|:--------|:-------------|:-------|
| Residual oscillates | KT and F_int inconsistent | FEM Engineer: check `computeTangentStiffnessAndForce` |
| Residual grows monotonically | Wrong residual sign | FEM Engineer: confirm `R = F_int − λF_ext` |
| `rcond ≈ 0` on step 1 | Fixed DOFs in linear system | FEM Engineer: confirm `KT(free_dofs, free_dofs)` |
| `p = 0` after plastic step | `commitHistory` not called | FEM Engineer: trace commit call |
| Correct path → diverges at limit point | Arc-length radius too large | VE: reduce `ArcLengthRadius` 50%; re-run |
| Snap-back not detected | CSP uses `dot(fext, dup)` | FEM Engineer: fix to `dot(dup_prev, dup_curr)` |
| Linear convergence (not quadratic) | ATM not consistent | FEM Engineer: check `integrateStress` returns exact ATM |

3. **Add targeted logging** (FEM Engineer if needed):
   - `fprintf('Iter %d: ||R_f|| = %.3e\n', i, norm(R(free_dofs)))`
   - `fprintf('rcond(KT_ff) = %.3e\n', rcond(KT(free_dofs,free_dofs)))`
   - `fprintf('dl = %.6f\n', dl)`

4. **Fix** (FEM Engineer): implement fix. Add a unit test that reproduces the failure and confirms the fix.

5. **Re-verify** (VE): run minimal case, then full benchmark suite. Confirm quadratic convergence in elastic regime.

6. **Document**: FEM Engineer writes session log entry with root cause. VE updates Verification Report with failure log row.

### Checklist
- [ ] Failure reproduced with minimal case
- [ ] Root cause identified from classification table
- [ ] Unit test added that catches the regression
- [ ] Full benchmark suite passes after fix
- [ ] Session log entry written

---

## WF-04 — run-verification

**Trigger**: "run verification | benchmarks | verify phase N | after src change"
**Owner**: Verification Engineer
**Output**: Verification Report

### Steps

1. Run Tier 1 — unit tests: `matlab -batch "setup_project; runtests('tests/unit')"`
2. Run Tier 2 — patch tests: `matlab -batch "setup_project; runtests('tests/Patchtest')"`
3. Run Tier 3 — benchmarks from task brief (or standard suite if no brief).
4. Run Tier 4 — data integrity checks (see VE instructions §4).
5. Produce required post-processing outputs.
6. Write Verification Report using Template 4.
7. Notify Architect.

### Checklist
- [ ] All four tiers run in order
- [ ] No tier skipped due to a prior-tier pass
- [ ] Each benchmark compared to its stated target
- [ ] Data integrity invariants all checked
- [ ] Report filed before notifying Architect

---

## WF-05 — review-architecture

**Trigger**: "architecture review | structural health | before refactor | class hierarchy"
**Owner**: Lead Architect (initiates), FEM Engineer (executes)
**Output**: Architecture notes in session log or standalone review document

### Steps

1. **Inventory** (FEM Engineer): list all `@Class` directories in `src/`. For each:
   - What does it inherit from?
   - Does it override methods unnecessarily (logic that belongs in the base)?
   - Does it duplicate logic from a sibling class?

2. **Interface audit** (FEM Engineer): verify consistent method signatures:
   - `[KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)`
   - `[Ke_global, fe_global, NewHist] = computeGlobalMatrix6DOF(obj, u_el)`
   - `[g, h, s] = constraintFn(u, l, u0, l0, dup, dlp, si)`
   - `[converged, U_out, reaction, iter] = newtonLoop(obj, F_ext, U_start, fixed_dofs)`

3. **Coupling check** (FEM Engineer): flag any case where:
   - A base class references a specific subclass by name
   - `buildElementCache` uses `strcmp` on type strings (fragile — prefer `isa`)
   - A solver contains logic that belongs in an element, or vice versa

4. **Technical debt register** (FEM Engineer): produce a table:

| Item | File | Severity | Recommended action |
|:-----|:-----|:---------|:-------------------|
| [e.g. assembleForArcLength duplicates assembleTangentSystem] | [file] | Medium | Unify |

5. **Report** (Lead Architect): record findings in session log or standalone document. Issue Phase N+1 task brief if refactor is warranted.

### Checklist
- [ ] All `@Class` directories inventoried
- [ ] Interface signatures verified
- [ ] Coupling issues documented
- [ ] Technical debt table produced
- [ ] Architect decision recorded

---

## WF-06 — sync-docs

**Trigger**: "Gate 2 reached for Phase N. Please sync docs." (from Lead Architect only)
**Owner**: Project Scribe
**Output**: Updated `index.md`, `PROJECT_ROADMAP.md`, `PROJECT_PLAN_REFACTORED.md`, closed task briefs

### Steps

1. Add row to `docs/dev_logs/index.md` — verify session log file exists before linking.
2. Update `docs/PROJECT_ROADMAP.md` checkboxes (`[x]` / `[/]` / `[ ]`).
3. Update `docs/PROJECT_PLAN_REFACTORED.md` — Status: COMPLETED, Date: today.
4. For each task brief in `docs/audit_tasks/` belonging to the closed phase:
   - Set `Status: COMPLETED`
   - Add `Report:` link — verify file exists
5. Scan all new documents for `file:///` paths — flag with `<!-- SCRIBE NOTE -->` comments.
6. Report to Architect: items updated, broken links flagged, missing files (if any).

### Checklist
- [ ] `index.md` entry added with valid file link
- [ ] Roadmap checkboxes correct
- [ ] Plan status and date updated
- [ ] All task briefs for this phase closed and linked
- [ ] `file:///` scan complete
- [ ] Confirmation sent to Architect
