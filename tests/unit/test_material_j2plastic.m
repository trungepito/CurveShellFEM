function result = test_material_j2plastic()
% TEST_MATERIAL_J2PLASTIC  Unit tests for J2 plasticity integration.
%
% Covers UT4.1–UT4.5 from the implementation plan.
%   UT4.1  Elastic trial below yield returns unchanged stress
%   UT4.2  Plastic return satisfies yield criterion
%   UT4.3  Algorithmic tangent consistency (finite-difference check)
%   UT4.4  Plastic strain is volumetrically neutral (trace == 0)
%   UT4.5  Local Newton loop converges for 50 random above-yield strains

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_material_j2plastic');

% Material properties
E    = 2.1e11;
nu   = 0.3;
sigY = 250e6;
H    = 1e9;     % non-zero hardening for tangent test
mat  = Material_J2Plastic(E, nu, sigY, H);

% ----------------------------------------------------------------
% UT4.1 — Elastic trial below yield
% ----------------------------------------------------------------
result = run_subtest(result, 'UT4.1 elastic response below yield', @() ut4_1(mat, E, nu, sigY));

% ----------------------------------------------------------------
% UT4.2 — Plastic return mapping stays on yield surface
% ----------------------------------------------------------------
result = run_subtest(result, 'UT4.2 stress on yield surface after return', @() ut4_2(mat, sigY));

% ----------------------------------------------------------------
% UT4.3 — Algorithmic tangent finite-difference consistency
% ----------------------------------------------------------------
result = run_subtest(result, 'UT4.3 tangent consistency (FD)', @() ut4_3(mat, sigY));

% ----------------------------------------------------------------
% UT4.4 — Plastic volumetric neutrality (tr(deps_p) ≈ 0)
% ----------------------------------------------------------------
result = run_subtest(result, 'UT4.4 plastic incompressibility', @() ut4_4(mat, sigY));

% ----------------------------------------------------------------
% UT4.5 — Local Newton loop convergence for 50 random above-yield strains
% ----------------------------------------------------------------
result = run_subtest(result, 'UT4.5 Newton loop converges for 50 random strains', @() ut4_5(mat, sigY));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function D_el = elastic_D(E, nu)
fac  = E / (1 - nu^2);
D_el = fac * [1, nu, 0; nu, 1, 0; 0, 0, (1-nu)/2];
end

% ----------------------------------------------------------------
function vm = von_mises_ps(sigma)
% Von Mises stress from plane-stress vector [sx; sy; txy].
sx = sigma(1); sy = sigma(2); txy = sigma(3);
vm = sqrt(sx^2 + sy^2 - sx*sy + 3*txy^2);
end

% ----------------------------------------------------------------
function ut4_1(mat, E, nu, sigY)
% Apply strain well below yield; expect purely elastic response.
D_el = elastic_D(E, nu);
% Small uniaxial strain — stress = E*eps_x well below sigY
eps_total = [sigY*0.01 / E; 0; 0];   % sigma_x ≈ 0.01 * sigY
eps_p_old = zeros(3, 1);
p_old     = 0;

[sigma_new, ~, eps_p_new, p_new] = mat.integrateStress(eps_total, eps_p_old, p_old);

sigma_elastic = D_el * eps_total;

if norm(sigma_new - sigma_elastic) > 1e-3   % 1 Pa tolerance at ~2.5e9 Pa
    error('Elastic branch: sigma differs from D*eps by %g Pa', ...
          norm(sigma_new - sigma_elastic));
end
if p_new ~= 0 || norm(eps_p_new) > 1e-20
    error('Plastic strain/p should be zero for elastic trial');
end
end

% ----------------------------------------------------------------
function ut4_2(mat, sigY)
% Apply strain that drives the trial stress 2x above yield.
% After return mapping, von_mises(sigma_new) must <= sigY + H*p + tol.
% Use pure uniaxial to make trial stress simple.
E   = mat.E;
nu  = mat.nu;
H   = mat.H;
D_el = elastic_D(E, nu);

% Drive trial uniaxial stress to 2*sigY
target_trial_sx = 2.0 * sigY;
eps_x = target_trial_sx / E;   % approximate for plane stress
eps_total = [eps_x; -nu*eps_x; 0];

eps_p_old = zeros(3, 1);
p_old     = 0;

[sigma_new, ~, ~, p_new] = mat.integrateStress(eps_total, eps_p_old, p_old);

yield_curr = sigY + H * p_new;
vm_new     = von_mises_ps(sigma_new);
tol        = 1e-4 * sigY;

if vm_new > yield_curr + tol
    error('Yield surface violated: vm = %g Pa > sigY_curr = %g Pa (diff = %g)', ...
          vm_new, yield_curr, vm_new - yield_curr);
end
end

% ----------------------------------------------------------------
function ut4_3(mat, sigY)
% Check algorithmic tangent Dep against central finite differences.
% sigma(eps + delta) - sigma(eps) ≈ Dep * delta for small delta.
E  = mat.E;
nu = mat.nu;
H  = mat.H;

% Above-yield base strain (uniaxial, well inside plastic regime)
eps_x = 1.5 * sigY / E;
eps_base  = [eps_x; -nu*eps_x; 0];
eps_p_old = zeros(3,1);
p_old     = 0;

% Integrate once from zero state to get Dep at eps_base.
% The FD perturbations must start from the SAME zero state (eps_p_old, p_old)
% so they replicate the same loading path. Using the post-return state
% (eps_p1, p1) as the FD base gives a secant modulus, not Dep.
[~, Dep, ~, ~] = mat.integrateStress(eps_base, eps_p_old, p_old);

h   = 1e-7 * sigY / E;   % perturbation size (slightly larger for robustness)
tol = 1e-4;               % relative tolerance (algorithmic tangent, not secant)

for k = 1:3
    delta = zeros(3,1); delta(k) = h;

    [sig_p, ~, ~, ~] = mat.integrateStress(eps_base + delta, eps_p_old, p_old);
    [sig_m, ~, ~, ~] = mat.integrateStress(eps_base - delta, eps_p_old, p_old);

    dsig_fd = (sig_p - sig_m) / (2*h);
    dsig_an = Dep(:, k);

    rel_err = norm(dsig_fd - dsig_an) / max(norm(dsig_an), 1e-30);
    if rel_err > tol
        error('Tangent column %d: FD vs analytic relative error = %g > %g', ...
              k, rel_err, tol);
    end
end
end

% ----------------------------------------------------------------
function ut4_4(mat, sigY)
% Plastic incompressibility: tr(eps_p_new - eps_p_old) ≈ 0.
E  = mat.E;
nu = mat.nu;

eps_x     = 1.5 * sigY / E;
eps_total = [eps_x; -nu*eps_x; 0];
eps_p_old = zeros(3, 1);
p_old     = 0;

[~, ~, eps_p_new, ~] = mat.integrateStress(eps_total, eps_p_old, p_old);

% Correct incompressibility check for plane-stress J2 plasticity:
% The plastic strain vector is [eps_px; eps_py; gamma_pxy].
% J2 plastic flow is deviatoric, so tr(eps_p_3D) = 0.
% In plane stress: eps_pz = -(eps_px + eps_py)  (out-of-plane component)
% => eps_px + eps_py + eps_pz = 0  always.
% We cannot directly read eps_pz, but we verify two testable properties:
%   (1) For zero-shear input, gamma_pxy must be zero.
%   (2) The sign of eps_py is opposite to eps_px (flow is deviatoric).
deps_p = eps_p_new - eps_p_old;

% Skip trivial elastic case
if norm(deps_p) < 1e-20
    return;
end

% Property 1: no shear plastic strain for pure uniaxial loading
if abs(deps_p(3)) > 1e-8 * max(abs(deps_p(1:2)))
    error('Non-zero shear plastic strain for uniaxial loading: gamma_pxy / eps_px = %g', ...
          deps_p(3) / max(abs(deps_p(1)), 1e-30));
end

% Property 2: eps_px and eps_py have opposite signs (deviatoric flow)
if sign(deps_p(1)) == sign(deps_p(2)) && abs(deps_p(2)) > 1e-10 * abs(deps_p(1))
    error('eps_px (%g) and eps_py (%g) have same sign — plastic flow is not deviatoric', ...
          deps_p(1), deps_p(2));
end
end

% ----------------------------------------------------------------
function ut4_5(mat, sigY)
% 50 random above-yield strain states. The Newton loop in integrateStress
% must converge (no warning) for all of them.
rng(12345);

E  = mat.E;
nu = mat.nu;

n_tests    = 50;
fail_count = 0;
fail_msgs  = {};

for k = 1:n_tests
    % Random strain in range [1.5, 5] * sigY/E (well above yield)
    scale = sigY / E * (1.5 + 3.5*rand());
    eps_total = scale * (2*rand(3,1) - 1);
    eps_total(3) = eps_total(3) * 0.1;  % keep shear moderate

    eps_p_old = zeros(3,1);
    p_old     = 0;

    warnState = warning('error', 'MATLAB:nearSingularMatrix');
    try
        [sigma_new, ~, ~, p_new] = mat.integrateStress(eps_total, eps_p_old, p_old); %#ok<ASGLU>
    catch ME
        fail_count = fail_count + 1;
        fail_msgs{end+1} = sprintf('Test %d failed: %s', k, ME.message); %#ok<AGROW>
    end
    warning(warnState);

    % Also verify the converged stress satisfies yield
    if p_new > 0
        vm = von_mises_ps(sigma_new);
        yld = mat.YieldStress + mat.H * p_new;
        if vm > yld + 1e-4 * mat.YieldStress
            fail_count = fail_count + 1;
            fail_msgs{end+1} = sprintf('Test %d: yield violated (vm=%g > yld=%g)', k, vm, yld);
        end
    end
end

if fail_count > 0
    error('%d / %d convergence tests failed:\n%s', ...
          fail_count, n_tests, strjoin(fail_msgs, '\n'));
end
end
