function result = test_elastic_plate_nonlinear()
% TEST_ELASTIC_PLATE_NONLINEAR  Integration tests for nonlinear plate solve.
%
% Covers IT2.1–IT2.4:
%   IT2.1  5-step LoadControl solve: StepCount == 5
%   IT2.2  U_Hist has 5 columns; Uz increases monotonically
%   IT2.3  Sol.state.StepCount == 5 (dependent property consistent)
%   IT2.4  recoverField('displacement_z', 5) matches Sol.U(3:6:end)

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_elastic_plate_nonlinear');

% ----------------------------------------------------------------
% Model: same clamped 1m x 1m plate, load in 5 equal increments
% ----------------------------------------------------------------
E  = 200e9;
nu = 0.3;
t  = 0.02;
L  = 1.0;
q  = 500;    % Pa per step (total 2.5 kPa across 5 steps)

Pre = make_plate_model('E', E, 'nu', nu, 't', t, 'L', L, 'Ne', 4, 'bc', 'clamped');

all_elems = (1 : size(Pre.Mesh.Elements, 1))';
Pre.addPressureLoad(all_elems, q, 'Pressure');

opts = SolverOptions();
opts.MaxIterations = 15;
opts.TolForce      = 1e-5;
Sol = FEM_Solver_Nonlinear(Pre, opts);

% 5-step load control
S1 = LoadingStage(1.0);
S1.ConstraintType  = 'LoadControl';
S1.ArcLengthRadius = 0.2;   % 5 equal steps of 0.2
S1.activateBC('Clamp');
S1.activateLoad('Pressure');

Sol.solve({S1});

nNodes = size(Pre.Mesh.Nodes, 1);

% ----------------------------------------------------------------
% IT2.1 — StepCount == 5
% ----------------------------------------------------------------
result = run_subtest(result, 'IT2.1 StepCount == 5', @() ...
    assert_equal(Sol.StepCount, 5, 0, 'StepCount'));

% ----------------------------------------------------------------
% IT2.2 — U_Hist has 5 columns; max(|Uz|) increases per step
% ----------------------------------------------------------------
result = run_subtest(result, 'IT2.2 U_Hist size and Uz monotone', ...
    @() it2_2(Sol));

% ----------------------------------------------------------------
% IT2.3 — state.StepCount consistent with dependent property
% ----------------------------------------------------------------
result = run_subtest(result, 'IT2.3 state.StepCount == 5', @() ...
    assert_equal(Sol.state.StepCount, 5, 0, 'state.StepCount'));

% ----------------------------------------------------------------
% IT2.4 — recoverField('displacement_z', 5) matches Sol.U
% ----------------------------------------------------------------
result = run_subtest(result, 'IT2.4 displacement_z field matches Sol.U', ...
    @() it2_4(Pre, Sol, nNodes));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function it2_2(Sol)
U_Hist = Sol.U_Hist;
if size(U_Hist, 2) ~= 5
    error('U_Hist has %d columns, expected 5', size(U_Hist, 2));
end

% Extract max |Uz| at each step
max_uz = zeros(5, 1);
for s = 1:5
    U_s     = Sol.state.getU(s);
    max_uz(s) = max(abs(U_s(3:6:end)));
end

% Must be monotonically increasing
for s = 2:5
    if max_uz(s) <= max_uz(s-1) - 1e-12
        error('max(|Uz|) not monotone: step %d (%g) <= step %d (%g)', ...
              s, max_uz(s), s-1, max_uz(s-1));
    end
end
end

% ----------------------------------------------------------------
function it2_4(Pre, Sol, nNodes)
Post  = FEM_Postprocessor_v2(Pre, Sol);
field = Post.recoverField('displacement_z', 5);

% Compare against Sol.U directly (last step)
U5    = Sol.state.getU(5);
uz5   = U5(3:6:end);

if length(field) ~= nNodes
    error('Field length %d != nNodes %d', length(field), nNodes);
end

% displacement_z is read directly from U, so must match exactly
if norm(field - uz5) > 1e-10
    error('displacement_z field deviates from Sol.U by %g', norm(field - uz5));
end
end
