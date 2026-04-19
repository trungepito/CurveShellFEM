function result = test_solver_options()
% TEST_SOLVER_OPTIONS  Unit tests for SolverOptions validation.
%
% Covers UT8.1–UT8.5 from the implementation plan.
%   UT8.1  Default values match the specification
%   UT8.2  validate() passes on a default-constructed object
%   UT8.3  validate() throws when MaxIterations < 3
%   UT8.4  validate() throws when NormType is unknown
%   UT8.5  validate() throws when MinDt >= MaxDt

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_solver_options');

% ----------------------------------------------------------------
% UT8.1 — Default values
% ----------------------------------------------------------------
result = run_subtest(result, 'UT8.1 default values correct', @() ut8_1());

% ----------------------------------------------------------------
% UT8.2 — validate() passes on default object
% ----------------------------------------------------------------
result = run_subtest(result, 'UT8.2 validate passes on defaults', @() ut8_2());

% ----------------------------------------------------------------
% UT8.3 — validate() throws when MaxIterations < 3
% ----------------------------------------------------------------
result = run_subtest(result, 'UT8.3 validate throws MaxIterations < 3', @() ut8_3());

% ----------------------------------------------------------------
% UT8.4 — validate() throws when NormType is unknown
% ----------------------------------------------------------------
result = run_subtest(result, 'UT8.4 validate throws bad NormType', @() ut8_4());

% ----------------------------------------------------------------
% UT8.5 — validate() throws when MinDt >= MaxDt
% ----------------------------------------------------------------
result = run_subtest(result, 'UT8.5 validate throws MinDt >= MaxDt', @() ut8_5());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function ut8_1()
opts = SolverOptions();

% Check every default value listed in the implementation plan.
checks = { ...
    'MaxIterations',  25; ...
    'TolForce',       1e-4; ...
    'TolDisp',        1e-3; ...
    'TolEnergy',      1e-7; ...
    'UseLineSearch',  false; ...
    'UseQuasiNewton', false; ...
    'LBFGSHistory',   6; ...
    'MemoryMode',     'all'; ...
    'NormType',       'force'; ...
};

for k = 1:size(checks, 1)
    fname  = checks{k, 1};
    fval   = checks{k, 2};
    actual = opts.(fname);
    if isnumeric(fval)
        if abs(actual - fval) > 0
            error('Default %s = %g, expected %g', fname, actual, fval);
        end
    elseif islogical(fval)
        if actual ~= fval
            error('Default %s = %d, expected %d', fname, actual, fval);
        end
    else
        if ~strcmp(actual, fval)
            error('Default %s = ''%s'', expected ''%s''', fname, actual, fval);
        end
    end
end
end

% ----------------------------------------------------------------
function ut8_2()
opts = SolverOptions();
% Must not throw
try
    opts.validate();
catch ME
    error('validate() threw on default SolverOptions: %s', ME.message);
end
end

% ----------------------------------------------------------------
function ut8_3()
opts = SolverOptions();
opts.MaxIterations = 2;   % below minimum of 3

errFired = false;
try
    opts.validate();
catch ME
    if contains(ME.identifier, 'MaxIterations') || contains(ME.message, 'MaxIterations')
        errFired = true;
    else
        error('validate threw unexpected error: %s', ME.identifier);
    end
end

if ~errFired
    error('validate() did not throw for MaxIterations = 2');
end
end

% ----------------------------------------------------------------
function ut8_4()
opts = SolverOptions();
opts.NormType = 'bad_norm';

errFired = false;
try
    opts.validate();
catch ME
    if contains(ME.identifier, 'NormType') || contains(ME.message, 'NormType') || ...
       contains(ME.message, 'norm')
        errFired = true;
    else
        error('validate threw unexpected error: %s  %s', ME.identifier, ME.message);
    end
end

if ~errFired
    error('validate() did not throw for NormType = ''bad_norm''');
end
end

% ----------------------------------------------------------------
function ut8_5()
opts = SolverOptions();
opts.MinDt = 0.5;
opts.MaxDt = 0.3;   % MinDt > MaxDt

errFired = false;
try
    opts.validate();
catch ME
    if contains(ME.identifier, 'MinDt') || contains(ME.message, 'MinDt') || ...
       contains(ME.message, 'MaxDt')
        errFired = true;
    else
        error('validate threw unexpected error: %s', ME.identifier);
    end
end

if ~errFired
    error('validate() did not throw for MinDt (%g) >= MaxDt (%g)', opts.MinDt, opts.MaxDt);
end

% Equal case: MinDt == MaxDt must also throw
opts2 = SolverOptions();
opts2.MinDt = opts2.MaxDt;
errFired2 = false;
try
    opts2.validate();
catch
    errFired2 = true;
end
if ~errFired2
    error('validate() did not throw for MinDt == MaxDt');
end
end
