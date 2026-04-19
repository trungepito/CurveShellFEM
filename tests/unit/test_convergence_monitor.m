function result = test_convergence_monitor()
% TEST_CONVERGENCE_MONITOR  Unit tests for ConvergenceMonitor.
%
% Covers UT2.1–UT2.7 from the implementation plan.
%   UT2.1  Force norm converges correctly
%   UT2.2  Energy norm is non-zero with non-empty dU
%   UT2.3  Displacement norm is non-zero with U_total
%   UT2.4  isDiverging fires on growing residuals
%   UT2.5  isStagnating fires on flat residuals
%   UT2.6  isOscillating fires on alternating residuals
%   UT2.7  recommend() returns correct strings

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_convergence_monitor');

% ----------------------------------------------------------------
% UT2.1 — Force norm: check returns true when ||R||/||F_ext|| < tol
% ----------------------------------------------------------------
result = run_subtest(result, 'UT2.1 force norm convergence', @() ut2_1());

% ----------------------------------------------------------------
% UT2.2 — Energy norm: ResidualHistory(1) > 0 when dU is non-empty
% ----------------------------------------------------------------
result = run_subtest(result, 'UT2.2 energy norm non-zero', @() ut2_2());

% ----------------------------------------------------------------
% UT2.3 — Displacement norm: ResidualHistory(1) > 0
% ----------------------------------------------------------------
result = run_subtest(result, 'UT2.3 displacement norm non-zero', @() ut2_3());

% ----------------------------------------------------------------
% UT2.4 — isDiverging: fires when residual grows by DivRatio
% ----------------------------------------------------------------
result = run_subtest(result, 'UT2.4 isDiverging fires correctly', @() ut2_4());

% ----------------------------------------------------------------
% UT2.5 — isStagnating: fires when progress < 5% over window
% ----------------------------------------------------------------
result = run_subtest(result, 'UT2.5 isStagnating fires correctly', @() ut2_5());

% ----------------------------------------------------------------
% UT2.6 — isOscillating: fires when residual alternates sign of slope
% ----------------------------------------------------------------
result = run_subtest(result, 'UT2.6 isOscillating fires correctly', @() ut2_6());

% ----------------------------------------------------------------
% UT2.7 — recommend() returns correct action strings
% ----------------------------------------------------------------
result = run_subtest(result, 'UT2.7 recommend() strings', @() ut2_7());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function ut2_1()
% Set up a converged scenario: ||R_free|| / ||F_ext_free|| < tol.
mon = ConvergenceMonitor();
mon.Tolerance = 1e-4;
mon.NormType  = 'force';

nf = 10;
F_ext_free = ones(nf, 1);         % ||F|| = sqrt(10)
mon.reset(F_ext_free);

R_small    = 1e-5 * ones(nf, 1);  % ratio = 1e-5/1 < 1e-4 → converged
dU_free    = zeros(nf, 1);
U_free     = ones(nf, 1);

converged = mon.check(R_small, dU_free, U_free, F_ext_free, 1);
if ~converged
    error('Expected convergence with ||R||/||F|| = %g < tol %g', ...
          norm(R_small)/norm(F_ext_free), mon.Tolerance);
end
end

% ----------------------------------------------------------------
function ut2_2()
% Energy norm: err = |dU' * R| / ref.  Must be > 0 when dU != 0.
mon = ConvergenceMonitor();
mon.Tolerance = 1e-6;
mon.NormType  = 'energy';

nf = 10;
F_ext_free = ones(nf, 1);
mon.reset(F_ext_free);

R_free  = 0.5 * ones(nf, 1);
dU_free = 0.1 * ones(nf, 1);    % non-empty — energy = |dU'*R| = 0.5 > 0
U_free  = ones(nf, 1);

mon.check(R_free, dU_free, U_free, F_ext_free, 1);

if isempty(mon.ResidualHistory) || mon.ResidualHistory(1) <= 0
    error('Energy norm residual is zero or empty — dU was empty or energy is wrong');
end
end

% ----------------------------------------------------------------
function ut2_3()
% Displacement norm: err = ||dU|| / max(||U||, floor).  Must be > 0.
mon = ConvergenceMonitor();
mon.Tolerance = 1e-5;
mon.NormType  = 'displacement';

nf = 10;
F_ext_free = ones(nf, 1);
mon.reset(F_ext_free);

R_free  = 0.1 * ones(nf, 1);
dU_free = 0.05 * ones(nf, 1);
U_free  = ones(nf, 1);         % ||U|| = sqrt(10)

mon.check(R_free, dU_free, U_free, F_ext_free, 1);

if isempty(mon.ResidualHistory) || mon.ResidualHistory(1) <= 0
    error('Displacement norm residual is zero or empty');
end
end

% ----------------------------------------------------------------
function ut2_4()
% isDiverging: feed 4 residuals growing by x10 each step.
% DivergenceRatio = 500 → ratio(end)/ratio(1) = 1000 > 500 → diverging.
mon = ConvergenceMonitor();
mon.DivRatio  = 500;
mon.NormType  = 'force';

nf = 5;
F_ext = ones(nf, 1);
mon.reset(F_ext);

residuals = [1, 10, 100, 1000];
dU  = zeros(nf, 1);
U   = ones(nf, 1);
for k = 1:4
    R = residuals(k) * ones(nf, 1);
    mon.check(R, dU, U, F_ext, k);
end

if ~mon.isDiverging()
    error('isDiverging should be true: ratio = %g > %g', ...
          mon.RawNormHistory(end)/mon.RawNormHistory(1), mon.DivRatio);
end
end

% ----------------------------------------------------------------
function ut2_5()
% isStagnating: residuals [1, 0.99, 0.98, 0.97, 0.96].
% Drop over window of 4 = (0.97-0.96)/0.97 ≈ 1% < 5% threshold.
mon = ConvergenceMonitor();
mon.StagnationWin = 4;
mon.NormType = 'force';

nf = 5;
F_ext = 100 * ones(nf, 1);   % large ref so ratio << 1
mon.reset(F_ext);

residuals = [1.0, 0.99, 0.98, 0.97, 0.96];
dU = zeros(nf, 1);
U  = ones(nf, 1);
for k = 1:5
    R = residuals(k) * ones(nf, 1);
    mon.check(R, dU, U, F_ext, k);
end

if ~mon.isStagnating()
    r = mon.RawNormHistory;
    w = mon.StagnationWin;
    drop = (r(end-w) - r(end)) / max(r(end-w), 1e-30);
    error('isStagnating should be true: progress = %.2f%% < 5%%', drop*100);
end
end

% ----------------------------------------------------------------
function ut2_6()
% isOscillating: residuals alternate up/down at least twice.
mon = ConvergenceMonitor();
mon.OscillDetect = true;
mon.NormType = 'force';

nf = 5;
F_ext = 100 * ones(nf, 1);
mon.reset(F_ext);

residuals = [1, 2, 1, 2, 1];
dU = zeros(nf, 1);
U  = ones(nf, 1);
for k = 1:5
    R = residuals(k) * ones(nf, 1);
    mon.check(R, dU, U, F_ext, k);
end

if ~mon.isOscillating()
    error('isOscillating should be true for alternating residuals [1,2,1,2,1]');
end
end

% ----------------------------------------------------------------
function ut2_7()
% recommend() returns 'abort' when diverging, 'cutback' when stagnating.

% --- abort scenario ---
mon_div = ConvergenceMonitor();
mon_div.DivRatio = 5;
mon_div.NormType = 'force';
nf = 3;
F = ones(nf, 1);
mon_div.reset(F);
for k = 1:4
    mon_div.check((10^k) * F, zeros(nf,1), F, F, k);
end
action_div = mon_div.recommend();
if ~strcmp(action_div, 'abort')
    error('recommend() should be ''abort'' when diverging, got ''%s''', action_div);
end

% --- cutback scenario ---
mon_stag = ConvergenceMonitor();
mon_stag.StagnationWin = 4;
mon_stag.NormType = 'force';
F2 = 1000 * ones(nf, 1);
mon_stag.reset(F2);
vals = [1.0, 0.99, 0.98, 0.97, 0.96];
for k = 1:5
    mon_stag.check(vals(k) * ones(nf,1), zeros(nf,1), ones(nf,1), F2, k);
end
action_stag = mon_stag.recommend();
if ~strcmp(action_stag, 'cutback')
    error('recommend() should be ''cutback'' when stagnating, got ''%s''', action_stag);
end
end
