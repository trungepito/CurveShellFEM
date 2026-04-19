function result = test_curve8element()
% TEST_CURVE8ELEMENT  Unit tests for Curve8Element fundamentals.
%
% Covers UT3.1–UT3.7 from the implementation plan.
%   UT3.1  fmisoq8 interpolates identity at each corner node
%   UT3.2  Partition of unity at 25 random points
%   UT3.3  Shape function derivatives vs finite differences
%   UT3.4  Constitutive matrix D_mb is symmetric positive-definite
%   UT3.5  Stiffness matrix is symmetric and PSD
%   UT3.6  Transformation T is orthogonal (T*T' = I)
%   UT3.7  Internal force at zero displacement is zero

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_curve8element');

% Build one flat 1m x 1m element
E  = 2.1e11;
nu = 0.3;
t  = 0.01;
[coords, normals] = make_single_element('Lx', 1.0, 'Ly', 1.0);
el = Curve8Element(coords, normals, t, E, nu);

% ----------------------------------------------------------------
% UT3.1 — fmisoq8 at each corner node: N_i(xi_i, eta_i) == delta_ij
% ----------------------------------------------------------------
result = run_subtest(result, 'UT3.1 Kronecker delta at corner nodes', @() ut3_1());

% ----------------------------------------------------------------
% UT3.2 — Partition of unity: sum(N) == 1 at 25 random points
% ----------------------------------------------------------------
result = run_subtest(result, 'UT3.2 partition of unity', @() ut3_2());

% ----------------------------------------------------------------
% UT3.3 — Derivative consistency: analytic vs finite difference
% ----------------------------------------------------------------
result = run_subtest(result, 'UT3.3 derivative consistency FD', @() ut3_3());

% ----------------------------------------------------------------
% UT3.4 — D_mb is symmetric positive-definite
% ----------------------------------------------------------------
result = run_subtest(result, 'UT3.4 D_mb is SPD', @() ut3_4(el));

% ----------------------------------------------------------------
% UT3.5 — Stiffness matrix symmetry and positive semi-definiteness
% ----------------------------------------------------------------
result = run_subtest(result, 'UT3.5 Ke symmetric and PSD', @() ut3_5(el));

% ----------------------------------------------------------------
% UT3.6 — Trans_T is orthogonal
% ----------------------------------------------------------------
result = run_subtest(result, 'UT3.6 T is orthogonal', @() ut3_6(el));

% ----------------------------------------------------------------
% UT3.7 — Internal force at zero displacement is zero
% ----------------------------------------------------------------
result = run_subtest(result, 'UT3.7 fe(0) == 0', @() ut3_7(el));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function ut3_1()
% Node ordering in fmisoq8:
%   nodes 1-4: corners (-1,-1),(1,-1),(1,1),(-1,1)
%   nodes 5-8: midsides (0,-1),(1,0),(0,1),(-1,0)
xi_nodes  = [-1,  1,  1, -1,  0,  1,  0, -1];
eta_nodes = [-1, -1,  1,  1, -1,  0,  1,  0];

tol = 1e-14;
for i = 1:8
    [N, ~] = Curve8Element.fmisoq8(xi_nodes(i), eta_nodes(i));
    for j = 1:8
        expected = double(i == j);
        if abs(N(j) - expected) > tol
            error('N_%d(%g,%g) = %g, expected %g (Kronecker delta violation)', ...
                  j, xi_nodes(i), eta_nodes(i), N(j), expected);
        end
    end
end
end

% ----------------------------------------------------------------
function ut3_2()
% sum(N) == 1 at 25 random points in [-1,1]^2.
rng(42);
pts_xi  = 2*rand(25,1) - 1;
pts_eta = 2*rand(25,1) - 1;
tol = 1e-13;
for k = 1:25
    [N, ~] = Curve8Element.fmisoq8(pts_xi(k), pts_eta(k));
    s = sum(N);
    if abs(s - 1) > tol
        error('sum(N) = %g at point (%g,%g), expected 1', ...
              s, pts_xi(k), pts_eta(k));
    end
end
end

% ----------------------------------------------------------------
function ut3_3()
% Finite-difference check of shape function derivatives.
% dN/dxi  ≈ (N(xi+h) - N(xi-h)) / (2h)
% dN/deta ≈ (N(eta+h) - N(eta-h)) / (2h)
rng(7);
test_pts = [0.3, -0.5; -0.7, 0.2; 0.1, 0.1];
h   = 1e-7;
tol = 1e-7;

for k = 1:size(test_pts, 1)
    xi  = test_pts(k, 1);
    eta = test_pts(k, 2);

    [~, der] = Curve8Element.fmisoq8(xi, eta);
    dN_dxi_analytic  = squeeze(der(1, :, :))';   % [1 x 8]
    dN_deta_analytic = squeeze(der(2, :, :))';

    [N_xip, ~] = Curve8Element.fmisoq8(xi+h, eta);
    [N_xim, ~] = Curve8Element.fmisoq8(xi-h, eta);
    dN_dxi_fd = (N_xip - N_xim) / (2*h);

    [N_etap, ~] = Curve8Element.fmisoq8(xi, eta+h);
    [N_etam, ~] = Curve8Element.fmisoq8(xi, eta-h);
    dN_deta_fd = (N_etap - N_etam) / (2*h);

    err_xi  = max(abs(dN_dxi_analytic  - dN_dxi_fd'));
    err_eta = max(abs(dN_deta_analytic - dN_deta_fd'));

    if err_xi > tol
        error('dN/dxi FD error = %g > %g at pt %d', err_xi, tol, k);
    end
    if err_eta > tol
        error('dN/deta FD error = %g > %g at pt %d', err_eta, tol, k);
    end
end
end

% ----------------------------------------------------------------
function ut3_4(el)
% D_mb must be symmetric and have all positive eigenvalues (SPD).
[D_mb, ~] = el.getConstitutiveMatrix();

sym_err = norm(D_mb - D_mb', 'fro');
if sym_err > 1e-14
    error('D_mb is not symmetric: ||D - D''|| = %g', sym_err);
end

evs = eig(D_mb);
if any(evs <= 0)
    error('D_mb has non-positive eigenvalue: min eig = %g', min(evs));
end
end

% ----------------------------------------------------------------
function ut3_5(el)
% 40-DOF mixed-basis stiffness matrix must be symmetric and PSD
% (6 rigid body modes expected before constraint application).
Ke = el.computeStiffnessMatrix();

% Symmetry
sym_err = norm(Ke - Ke', 'fro') / max(norm(Ke, 'fro'), 1e-30);
if sym_err > 1e-10
    error('Ke is not symmetric: relative ||K-K''|| = %g', sym_err);
end

% PSD: all eigenvalues >= -eps_rel * ||Ke||
evs = eig((Ke + Ke') / 2);
eps_psd = 1e-10 * max(abs(evs));
if any(evs < -eps_psd)
    error('Ke has negative eigenvalue: min eig = %g', min(evs));
end
end

% ----------------------------------------------------------------
function ut3_6(el)
% T_hybrid (48x48) must satisfy T * T' = I.
T = el.T_cached;
I_approx = T * T';
err = norm(I_approx - eye(48), 'fro');
if err > 1e-10
    error('T * T'' deviates from I by %g (T is not orthogonal)', err);
end
end

% ----------------------------------------------------------------
function ut3_7(el)
% Internal force vector at u = 0 must be zero.
u_zero = zeros(48, 1);
[~, fe, ~] = el.computeGlobalMatrix6DOF(u_zero);
nrm = norm(fe);
if nrm > 1e-12
    error('||fe(0)|| = %g, expected 0 (no prestress at reference config)', nrm);
end
end
