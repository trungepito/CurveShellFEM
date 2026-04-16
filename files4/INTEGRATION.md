# E1–E6 integration guide

## Files delivered

| File | Drop into | Replaces |
|---|---|---|
| `src/@SolverOptions/SolverOptions.m` | `src/@SolverOptions/` | existing file |
| `src/@ConvergenceMonitor/ConvergenceMonitor.m` | `src/@ConvergenceMonitor/` | **new class** |
| `src/@FEM_Solver_Nonlinear/newtonLoop.m` | `src/@FEM_Solver_Nonlinear/` | existing file |
| `src/@FEM_Solver_Nonlinear/armijoSearch.m` | `src/@FEM_Solver_Nonlinear/` | **new method** |
| `src/@FEM_Solver_Nonlinear/lbfgsDirection.m` | `src/@FEM_Solver_Nonlinear/` | **new method** |
| `src/@FEM_Solver_ArcLength/arcLengthStep.m` | `src/@FEM_Solver_ArcLength/` | existing file |
| `src/@FEM_Solver_ArcLength/solveArcLengthStage.m` | `src/@FEM_Solver_ArcLength/` | existing file |

No other files need to change. All existing example scripts run unmodified
because every enhancement flag defaults to the pre-enhancement behaviour.

---

## Enabling enhancements

```matlab
opts = SolverOptions();

% E1 — tighter energy criterion (always active, values below are defaults)
opts.TolForce   = 1e-4;
opts.TolDisp    = 1e-3;
opts.TolEnergy  = 1e-7;

% E2 — Armijo line search
opts.UseLineSearch = true;
opts.MaxLineIter   = 8;
opts.ArmijoC1      = 1e-4;

% E3 — L-BFGS quasi-Newton (cuts assembly cost for large elastic problems)
opts.UseQuasiNewton  = true;
opts.LBFGSHistory    = 6;
opts.ResetOnPlastic  = true;   % reset on new yield (recommended)

% E4 — curvature-aware arc-length radius (always active in ArcLength solver)
opts.DesiredIters    = 4;
opts.ArcCurvatureWt  = 0.4;   % 0 = Ramm only, 1 = Bergan only

% E5 — predictor switching
opts.PredictorType   = 'auto';  % 'tangent' | 'secant' | 'auto'
opts.CondLimit       = 1e10;

% E6 — monitor thresholds
opts.StagnationWindow = 4;
opts.DivergenceRatio  = 1e3;
```

---

## Recommended settings per analysis type

### Linear-range nonlinear (geometric NL, no plasticity)
```matlab
opts.UseLineSearch  = true;
opts.UseQuasiNewton = true;   % biggest speedup here
opts.PredictorType  = 'auto';
```

### Snap-through / snap-back (arc-length)
```matlab
opts.UseLineSearch   = true;
opts.PredictorType   = 'auto';
opts.DesiredIters    = 4;
opts.ArcCurvatureWt  = 0.5;   % weight curvature more near limit points
```

### Plastic collapse (J2, large plastic strains)
```matlab
opts.UseLineSearch      = true;
opts.UseQuasiNewton     = true;
opts.ResetOnPlastic     = true;  % always true for plasticity
opts.TolEnergy          = 1e-6;  % slightly looser for path-dependent problems
```

---

## Backward compatibility

`newtonLoop` now has a 5th output argument `diagOut` (struct with fields
`force`, `disp`, `energy` — one value per Newton iteration). Callers that
request only 4 outputs are unaffected.

The `Tolerance` / `tol` / `maxIter` / `linesearch` properties on
`SolverOptions` continue to work as before via dependent-property setters.

---

## Math corrections vs original proposal (summary)

| Issue | Fix |
|---|---|
| E1 energy reference recomputed per iter | Fixed at iteration 1 |
| E1 floor parameters conflated units | Separate `DispFloor` / `EnergyFloor` |
| E2 used `assembleTangentSystem` inside LS loop | Uses `assembleinternalforceONLY` (3–10x cheaper) |
| E2 Armijo condition sign ambiguous | Residual-norm sufficient-decrease form |
| E3 curvature check `y'*s > 0` admits near-zero | Threshold `LBFGSCurvEps = 1e-10` |
| E3 pairs stored as full-DOF vectors | Stored on `free_dofs` only |
| E4 curvature range asymmetric `[0.7,1.3]` | `0.5*(1+cos_theta)` symmetric, floor 0.25 |
| E5 secant predictor lost arc-length scale | Unit direction; `dlp` scaling applied uniformly |
| E6 oscillation checked `diff(diff(R))` | Checks `diff(R)` (first differences); needs 4 points |
