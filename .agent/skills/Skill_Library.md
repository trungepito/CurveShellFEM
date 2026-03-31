# Skill Library (v3.0)

Skills are reference documents — the distilled right way to do recurring technical tasks.
Read the relevant skill before acting. Skills encode hard-won lessons from prior phases.

| ID | Skill | Read before |
|:---|:------|:------------|
| SK-01 | Shell element formulation | Any new `Curve8Element_*` |
| SK-02 | J2 plasticity & return mapping | Any `Material_*` work |
| SK-03 | Arc-length solver | Any arc-length modification |
| SK-04 | Sparse assembly patterns | Any assembly code |
| SK-05 | History variable management | Any stateful element or solver work |
| SK-06 | Class hierarchy rules | Any new class or inheritance change |
| SK-07 | Convergence diagnosis | Any convergence failure |
| SK-08 | Benchmark setup | Any benchmark execution |
| SK-09 | Mesh quality | Any mesh generation or preprocessor change |
| SK-10 | Post-processing & stress recovery | Any postprocessor work |

---

## SK-01 — Shell Element Formulation

### DOF layout
- **Local (40-DOF)**: 5 DOFs/node — [u, v, w, α, β] — 8 nodes
- **Global (48-DOF)**: 6 DOFs/node — [u, v, w, Rv1, Rv2, Wz] — 8 nodes
- Drilling DOF Wz is stabilised: `k_drill = 1e-4 × mean(diag(Ke_mixed))` — never hardcode

### Transformation chain
```
Global 48  →  T_hybrid  →  48 local  →  strip Wz  →  40  →  per_5_blkdiag  →  mixed basis
```
`T_hybrid` is cached in `obj.T_cached` at construction. Never recompute per Newton step.

### Node ordering
(-1,-1), (1,-1), (1,1), (-1,1), (0,-1), (1,0), (0,1), (-1,0)

### Integration scheme (base element)
| Component | Rule |
|:----------|:-----|
| Membrane/bending | 3×3 Gauss in-plane |
| Shear | 2×2 Gauss in-plane (reduced — prevents shear locking) |
| Plasticity (tangent) | 2×2 Gauss in-plane × 5 Simpson through-thickness |

### ANS (Bathe-Dvorkin) — transverse shear locking mitigation
- γ_ξz: sample at A=(0,+1) and B=(0,−1)
- γ_ηz: sample at C=(+1,0) and D=(−1,0)
- `γ̄_ξz = ½(1+η)·γ_ξz^A + ½(1−η)·γ_ξz^B`
- `γ̄_ηz = ½(1+ξ)·γ_ηz^C + ½(1−ξ)·γ_ηz^D`

### EAS (4-parameter Simo-Rifai) — membrane locking mitigation
Must satisfy: M(0,0) = 0 (patch test) and ∫M dV = 0 (orthogonality to constant stress).
Static condensation:
```
K_e = K_uu − K_uα · K_αα⁻¹ · K_αu
```
K_αα condition number < 10 confirms a well-conditioned condensation.

### Zero-energy mode count (correct values)
| Element | Zero modes | Notes |
|:--------|:----------|:------|
| Base `Curve8Element` (3×3 membrane) | 6 | Rigid body only — correct |
| With ANS only | 6 | Correct |
| With EAS (removes under-integration modes) | 6 | EAS eliminates spurious modes present in under-integrated baseline |

---

## SK-02 — J2 Plasticity & Return Mapping

### Yield function (plane stress)
`f = σ_VM − (σ_Y + H·p)`
`σ_VM = √(σx² + σy² − σx·σy + 3τxy²)`

### Algorithm (backward Euler, iterative Newton)

1. Trial stress: `σ_trial = D_el · (ε_total − ε_p_old)`
2. Elastic check: `f_trial ≤ 1e-6·σ_Y` → return `σ = σ_trial`, `D_ep = D_el`
3. Plastic return: solve `M·σ = σ_trial` where `M = I + ΔΓ·D_el·P` iteratively
   - Newton update: `ΔΓ_{k+1} = ΔΓ_k − φ/φ'`
   - Damping factor: 0.8 on Newton step (prevents oscillation near sharp limit)
   - Convergence: `|φ| < 1e-8·σ_Y`

### Consistent Algorithmic Tangent (ATM) — exact form
```
n = (1/σ_VM) · [σx − ½σy; σy − ½σx; 3τxy]   (at converged ΔΓ)
D_r = (M \ D_el)
D_ep = D_r − (D_r·n·n'·D_r) / (n'·D_r·n + H)
```
**Critical**: compute D_ep at the converged ΔΓ, never at the trial state. Trial-state tangent causes loss of quadratic convergence.

### History struct per Gauss point
```matlab
struct('sigma', zeros(3,1), 'eps_p', zeros(3,1), 'p', 0)
```
Count: 2×2 Gauss in-plane × 5 Simpson = 20 per element.

---

## SK-03 — Arc-Length Solver

### Modified Riks / Hyperplane constraint
```
g = dup' · (u − u₁) + ψ²·dlp·(λ − λ₁) = 0
u₁ = u₀ + dlp·dup,   λ₁ = λ₀ + dlp
h = dup   (∂g/∂u)
s = ψ²·dlp   (∂g/∂λ)
```
**Guard**: if `|s| < 1e-14`, set `s = arc_length·ψ²` — prevents denominator collapse on step 1.

### Corrector — augmented Newton on free DOFs only
```
KT_ff · du_I   =  fext_f        (tangent load direction)
KT_ff · du_II  = −R_f           (equilibrium correction)
dλ = −(g + h_f'·du_II) / (s + h_f'·du_I)
du(free_dofs) = dλ·du_I + du_II
```
**Never** pass the full system to backslash — fixed-DOF rows make it rank-deficient.

### Residual sign (correct)
`R = F_int − λ·F_ext`
The assembly closure must zero `R(fixed_dofs)` after building it.

### Convergence criterion (correct)
`‖R(free_dofs)‖ ≤ tol · ‖fext(free_dofs)‖`
Never use `‖R‖` (full vector) — fixed-DOF zeros dilute it and cause false convergence.

### CSP sign for snap-back detection (correct)
```matlab
k0 = dot(dup_prev, dup_curr)   % dup_curr = KT_ff \ fext_f
```
If `k0 < 0`: snap-back → negate `dlp`.
**Wrong**: `dot(fext, dup)` — always positive for SPD systems, cannot detect snap-back.

### Adaptive radius policy
| Condition | Action |
|:----------|:-------|
| iters ≤ 4 | `arc = min(arc × 1.5, arc_max)` |
| 4 < iters ≤ 0.75·maxit | `arc` unchanged |
| iters > 0.75·maxit | `arc = max(arc × 0.7, arc_min)` |
| Trial fails | `arc = max(arc × 0.5, arc_min)`, retry (max 5 trials) |

---

## SK-04 — Sparse Assembly Patterns

### Triplet assembly — the correct pattern
```matlab
nz = 48*48 * nElems;
I = zeros(nz,1); J = zeros(nz,1); V = zeros(nz,1);
count = 0;
[ii_base, jj_base] = ndgrid(1:48, 1:48);   % compute once outside loop

for e = 1:nElems
    sctr = obj.SctrMap(e,:);
    [Ke, fe, ~] = obj.Elements{e}.computeGlobalMatrix6DOF(u_el);
    range = count + (1:48*48);
    I(range) = sctr(ii_base(:));
    J(range) = sctr(jj_base(:));
    V(range) = Ke(:);
    count = count + 48*48;
end
K = sparse(I(1:count), J(1:count), V(1:count), nDofs, nDofs);
```
**Never**: `K(sctr,sctr) = K(sctr,sctr) + Ke` inside a loop — re-allocates on every iteration.

### SctrMap — compute once in `buildElementCache`
```matlab
sctr = zeros(1, 48);
for n = 1:8
    start_dof = (double(idx(n)) - 1) * 6;   % double() prevents int32 overflow
    local_start = (n-1) * 6;
    sctr(local_start+1 : local_start+6) = start_dof + (1:6);
end
obj.SctrMap(e,:) = sctr;
```

---

## SK-05 — History Variable Management

### The trial-commit pattern (mandatory)
```
assembleTangentSystem → element returns TrialHist
       ↓
Newton converges?
  YES → solver.commitHistory(TrialHist) → element.HistoryData updated
  NO  → TrialHist discarded; element.HistoryData unchanged
```

### `commitHistory` implementation
```matlab
function commitHistory(obj, TrialHist)
    if isempty(TrialHist), return; end
    for e = 1:length(obj.Elements)
        if isprop(obj.Elements{e}, 'HistoryData') && ~isempty(TrialHist{e})
            obj.Elements{e}.HistoryData = TrialHist{e};
        end
    end
end
```

### Initialisation in `buildElementCache`
```matlab
nGP = 4 * 5;   % 2×2 Gauss × 5 Simpson
init_h = struct('sigma', zeros(3,1), 'eps_p', zeros(3,1), 'p', 0);
hist = repmat(init_h, nGP, 1);
obj.Elements{e} = Curve8Element(coords, normals, t, E, nu, mat.Obj, hist);
```

### Diagnostic 
After a converged plastic step, `max([Sol.Elements{:}.HistoryData].p)` must be > 0 in yielded elements. If all zeros: `commitHistory` was not called.

---

## SK-06 — Class Hierarchy Rules

### Inheritance chain
```
handle
  └── FEM_Solver
        └── FEM_Solver_Nonlinear  (+events: StepConverged)
              ├── FEM_Solver_Adaptive
              │     └── FEM_Solver_ArcLength
              └── (future: FEM_Solver_DynamicImplicit)

handle
  └── Curve8Element
        ├── Curve8Element_ANS_EAS
        ├── Curve8Element_GNI
        └── (future: Curve8Element_Thermal)
```

### Rules
- Subclasses override only differing methods. Never copy a base method into a subclass unchanged.
- `newtonLoop`, `commitHistory`, `calculateGlobalTargetForce`, `getDispload`, `linesearch` live in `FEM_Solver_Nonlinear` and are never duplicated.
- `events` block lives only in `FEM_Solver_Nonlinear`. Subclasses call `notify(obj, 'StepConverged', evtData)`.
- `buildElementCache` dispatch: prefer `isa(mat.Obj, 'Material_J2Plastic')` over `strcmp(mat.Type, 'J2Plastic')`.
- Do not create a new class for a change that can be expressed as a property flag on an existing class.

---

## SK-07 — Convergence Diagnosis

### Quick classification table

| Symptom | Most likely cause | Fix owner |
|:--------|:----------------|:----------|
| Residual oscillates | KT inconsistent with F_int | FEM Eng: check `computeTangentStiffnessAndForce` pair |
| Residual grows monotonically | Wrong residual sign | FEM Eng: confirm `R = F_int − λF_ext` |
| Converges in 1 iteration always | Criterion on full R, not free-DOF R | FEM Eng: confirm `norm(R(free_dofs))` |
| `rcond(KT_ff) ≈ 0` on step 1 | Fixed DOFs in linear system | FEM Eng: confirm `KT(free_dofs, free_dofs)` used |
| `p = 0` everywhere after plastic step | `commitHistory` not called | FEM Eng: trace commit call |
| Correct path, diverges at limit point | Arc-length radius too large | VE: reduce `ArcLengthRadius` 50%, re-run |
| Snap-back not detected | CSP uses `dot(fext, dup)` | FEM Eng: fix to `dot(dup_prev, dup_curr)` |
| Linear convergence (not quadratic) | ATM not consistent | FEM Eng: check `integrateStress` returns exact ATM |
| `condest` error / singular warning | Type mismatch in scatter indices | FEM Eng: confirm `double(idx(n))` before arithmetic |

---

## SK-08 — Benchmark Setup & Reporting

### Standard benchmarks

| Benchmark | Reference | Metric | Target |
|:----------|:----------|:-------|:-------|
| Scordelis-Lo Roof | Scordelis & Lo (1964) | Max vertical disp at free edge | Error < 0.2% vs. 0.3024 |
| Pinched Cylinder | Macneal & Harder (1985) | DOF count + displacement | Exact regression match |
| ANS/EAS curved (R=300, t=3) | Internal | Stiffness trace ratio | < 1.0 (softer than base) |
| Plastic snap-through | Crisfield (1981) | Limit point traversal; p > 0 | Converges; no state leak |
| Buckling plate | Timoshenko & Gere | P_cr | Error < 2% vs. theory |
| GMNIA cylinder | Internal | Equilibrium path | Converges through limit point |

### Benchmark script pattern
```matlab
Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createCylinderPanel(...);
Pre.meshAllPatches(20, 20);
Pre.addBC(...); Pre.addNodalLoad(...);

Sol = FEM_Solver(Pre);
Sol.solveStatic();

u_max = max(abs(Sol.U(3:6:end)));
ref = 0.3024;
err_pct = abs(u_max - ref) / ref * 100;
fprintf('Error: %.4f%%\n', err_pct);
assert(err_pct < 0.2, 'FAIL: Scordelis-Lo');
```

---

## SK-09 — Mesh Quality Assessment

### Jacobian check (run after any new mesh generator)
```matlab
function ok = checkMeshDistortion(Pre, threshold)
% threshold: max det(J) ratio per element — recommended 10
nElems = size(Pre.Mesh.Elements, 1);
ok = true;
[g_pts, ~] = MathFEM.Gauss_p(2);
for e = 1:nElems
    idx = Pre.Mesh.Elements(e,:);
    el = Curve8Element(Pre.Mesh.Nodes(idx,:), Pre.Mesh.Normals(idx,:), ...
                       Pre.Material.t, Pre.Material.E, Pre.Material.nu);
    [xi, eta] = ndgrid(g_pts, g_pts);
    [detJ, ~, ~, ~] = el.calculateKinematics(xi(:), eta(:));
    if any(detJ <= 0)
        fprintf('Element %d: negative Jacobian\n', e); ok = false;
    elseif max(detJ)/min(detJ) > threshold
        fprintf('Element %d: distortion ratio %.1f\n', e, max(detJ)/min(detJ));
    end
end
end
```

### Node fusion tolerance
- Default: `1e-5` (safe for shortest edge > 1e-3)
- For fine meshes: `tol = min_edge_length / 100`
- After `fuseNodes`: node count should reduce by exactly the number of shared interface nodes.

### Normal consistency
- All normals should point outward (or consistently inward) for the shell surface.
- Check: for a flat plate in the XY plane, all normals should be [0,0,±1] with consistent sign.

---

## SK-10 — Post-Processing & Stress Recovery

### Load-displacement curve (arc-length results)
```matlab
u_node = Sol.U_Hist(control_dof, 1:Sol.StepCount);
lambda  = Sol.LambdaHist;
plot(u_node, lambda, '-o');
xlabel('Displacement'); ylabel('Load factor \lambda');
```
**Do not** use `abs()` on either axis. Negative λ and negative displacement are physically meaningful in snap-back.

### Through-thickness yield front
For each element, at each 2×2 Gauss point, count the fraction of the 5 Simpson layers with `p > 0`. Map this scalar (0 = elastic, 1 = fully yielded) to a colour on the shell surface via `recoverPlasticFront` + `plotPlasticYield`.

### SPR stress recovery (preferred over simple averaging)
1. For each node, collect stress values from all Gauss points of surrounding elements.
2. Fit a linear polynomial to the GP values (least squares).
3. Evaluate at the node location.

Simple averaging (`mean` of GP stresses) is acceptable for quick checks but underestimates peak stress at boundaries and singularities.

### App slider update pattern (no `cla()`)
```matlab
% Wrong — clears and redraws:
cla(ax); patch(ax, ...);

% Right — update in place:
set(surf_handle, 'CData', new_stress_values);
set(surf_handle, 'Vertices', deformed_nodes);
```
In-place update is required for smooth step scrubbing in the MATLAB App.
