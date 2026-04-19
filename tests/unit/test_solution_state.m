function result = test_solution_state()
% TEST_SOLUTION_STATE  Unit tests for SolutionState and SolutionSnapshot.
%
% Covers UT5.1–UT5.5 from the implementation plan.
%   UT5.1  'all' mode: StepCount and U_Hist dimensions after 10 appends
%   UT5.2  'rolling' mode: memory fixed at RollingWindow, eviction error fires
%   UT5.3  snapshot() is an independent copy
%   UT5.4  beginStage() increments StageCount
%   UT5.5  setEigenResults stores modes correctly

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_solution_state');

nDofs = 60;   % small DOF count sufficient for unit tests

% ----------------------------------------------------------------
% UT5.1 — 'all' mode: append 10 steps
% ----------------------------------------------------------------
result = run_subtest(result, 'UT5.1 all-mode StepCount and U_Hist size', @() ut5_1(nDofs));

% ----------------------------------------------------------------
% UT5.2 — 'rolling' mode: memory fixed, eviction error fires
% ----------------------------------------------------------------
result = run_subtest(result, 'UT5.2 rolling mode memory and eviction', @() ut5_2(nDofs));

% ----------------------------------------------------------------
% UT5.3 — snapshot() returns independent copy
% ----------------------------------------------------------------
result = run_subtest(result, 'UT5.3 snapshot is independent copy', @() ut5_3(nDofs));

% ----------------------------------------------------------------
% UT5.4 — beginStage() increments StageCount
% ----------------------------------------------------------------
result = run_subtest(result, 'UT5.4 beginStage increments StageCount', @() ut5_4(nDofs));

% ----------------------------------------------------------------
% UT5.5 — setEigenResults stores modes
% ----------------------------------------------------------------
result = run_subtest(result, 'UT5.5 setEigenResults / snapshot.ModeShapes', @() ut5_5(nDofs));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function ut5_1(nDofs)
opts = SolverOptions();
opts.MemoryMode = 'all';
state = SolutionState(nDofs, opts);

for k = 1:10
    U = k * ones(nDofs, 1);
    state.appendStep(U, k * 0.1, [], [], 0.05);
end

if state.StepCount ~= 10
    error('StepCount = %d, expected 10', state.StepCount);
end

hist = state.U_Hist(:, 1:state.StepCount);
if size(hist, 2) ~= 10
    error('U_Hist has %d columns, expected 10', size(hist, 2));
end

% Verify content: column k should be k * ones
for k = 1:10
    if abs(hist(1, k) - k) > 1e-12
        error('U_Hist(:,%d)(1) = %g, expected %g', k, hist(1,k), k);
    end
end
end

% ----------------------------------------------------------------
function ut5_2(nDofs)
win  = 5;
opts = SolverOptions();
opts.MemoryMode    = 'rolling';
opts.RollingWindow = win;
state = SolutionState(nDofs, opts);

% Append 20 steps
for k = 1:20
    U = k * ones(nDofs, 1);
    state.appendStep(U, k * 0.1, [], [], 0.05);
end

% Memory check: U_Hist must have exactly RollingWindow columns.
% The array is a circular buffer of fixed size win.
[~, actual_cols] = size(state.U_Hist);
if actual_cols ~= win
    error('Rolling buffer has %d columns, expected %d (RollingWindow)', ...
          actual_cols, win);
end

% getU(20) must succeed (within window: steps 16-20 are available)
U20 = state.getU(20);
if abs(U20(1) - 20) > 1e-12
    error('getU(20)(1) = %g, expected 20', U20(1));
end

% getU(14) must throw SolutionState:evicted
% (oldest valid = 20 - 5 + 1 = 16)
errFired = false;
try
    state.getU(14);
catch ME
    if contains(ME.identifier, 'evicted')
        errFired = true;
    else
        error('getU(14) threw unexpected error: %s', ME.identifier);
    end
end
if ~errFired
    error('getU(14) should throw SolutionState:evicted but did not');
end
end

% ----------------------------------------------------------------
function ut5_3(nDofs)
opts = SolverOptions();
opts.MemoryMode = 'all';
state = SolutionState(nDofs, opts);

for k = 1:5
    state.appendStep(k * ones(nDofs, 1), k * 0.1, [], [], 0.05);
end

snap = state.snapshot();

% Verify StepCount matches
if snap.StepCount ~= 5
    error('Snapshot StepCount = %d, expected 5', snap.StepCount);
end

% Modify snapshot — must not affect state
snap.U_Hist(:, 1) = 999 * ones(nDofs, 1);
if abs(state.U_Hist(1, 1) - 1.0) > 1e-12
    error('Modifying snapshot changed state.U_Hist (not a copy)');
end

% Read from snapshot via getU
U5 = snap.getU(5);
if abs(U5(1) - 5.0) > 1e-12
    error('snap.getU(5)(1) = %g, expected 5', U5(1));
end
end

% ----------------------------------------------------------------
function ut5_4(nDofs)
opts = SolverOptions();
state = SolutionState(nDofs, opts);

if state.StageCount ~= 0
    error('Initial StageCount = %d, expected 0', state.StageCount);
end

state.beginStage();
state.beginStage();
state.beginStage();

if state.StageCount ~= 3
    error('StageCount = %d after 3 beginStage calls, expected 3', state.StageCount);
end
end

% ----------------------------------------------------------------
function ut5_5(nDofs)
opts = SolverOptions();
state = SolutionState(nDofs, opts);

nModes  = 3;
modes   = rand(nDofs, nModes);
factors = [10.5; 22.3; 35.1];

state.setEigenResults(modes, factors);

snap = state.snapshot();

if ~isequal(size(snap.ModeShapes), [nDofs, nModes])
    error('snapshot ModeShapes size [%d %d], expected [%d %d]', ...
          size(snap.ModeShapes, 1), size(snap.ModeShapes, 2), nDofs, nModes);
end

if norm(snap.ModeShapes - modes, 'fro') > 1e-12
    error('snapshot ModeShapes do not match stored modes');
end

if norm(snap.BucklingFactors - factors) > 1e-12
    error('snapshot BucklingFactors do not match stored factors');
end
end
