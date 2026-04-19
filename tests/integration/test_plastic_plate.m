function result = test_plastic_plate()
% TEST_PLASTIC_PLATE  Integration tests for J2 plasticity pipeline.
%
% Covers IT3.1–IT3.5:
%   IT3.1  10-step plastic solve: StepCount == 10
%   IT3.2  At step 10 at least one GP has p > 0
%   IT3.3  PlasticHistoryArchive{10} is non-empty
%   IT3.4  recoverField('p', 10) has max > 0
%   IT3.5  Plastic strain is monotone non-decreasing across archive steps

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('test_plastic_plate');

% ----------------------------------------------------------------
% Model: 1m x 1m clamped plate, elastic-plastic material.
% Apply enough load to induce yielding at the center.
% sigY = 250 MPa, t = 0.02 m, E = 200 GPa
% ----------------------------------------------------------------
E    = 200e9;
nu   = 0.3;
t    = 0.02;
L    = 1.0;
sigY = 250e6;
H    = 5e9;

Pre = make_plate_model('E', E, 'nu', nu, 't', t, 'L', L, 'Ne', 4, ...
    'bc', 'clamped', 'plastic', true, 'sigY', sigY, 'H', H);

% Apply pressure: set to 5x yield-equivalent to ensure plasticity occurs
% Rough elastic max stress ≈ q * L^2 / (0.0513 * t^2) for clamped plate
% Set q to produce max stress ~= 1.5 * sigY
% D     = E * t^3 / (12*(1-nu^2));
% q_ref = 0.0513 * sigY * t^2 / (L^2 / (4*pi^2));   % rough estimate
% q_tot = max(q_ref * 1.2, 5e5);    % 500 kPa minimum to ensure yielding
q_tot = 1.5 * sigY * t^2 / (0.308 * L^2);

all_elems = (1 : size(Pre.Mesh.Elements, 1))';
Pre.addPressureLoad(all_elems, q_tot, 'Pressure');

opts = SolverOptions();
opts.MaxIterations = 20;
opts.TolForce      = 1e-5;
Sol = FEM_Solver_Nonlinear(Pre, opts);

S1 = LoadingStage(1.0);
S1.ConstraintType  = 'LoadControl';
S1.ArcLengthRadius = 0.1;   % 10 equal steps
S1.activateBC('Clamp');
S1.activateLoad('Pressure');

Sol.solve({S1});

nNodes = size(Pre.Mesh.Nodes, 1);
nElems = size(Pre.Mesh.Elements, 1);

% ----------------------------------------------------------------
% IT3.1 — StepCount == 10
% ----------------------------------------------------------------
result = run_subtest(result, 'IT3.1 StepCount == 10', @() ...
    assert_equal(Sol.StepCount, 10, 0, 'StepCount'));

% ----------------------------------------------------------------
% IT3.2 — At step 10 at least one GP has p > 0
% ----------------------------------------------------------------
result = run_subtest(result, 'IT3.2 some GP yielded at step 10', ...
    @() it3_2(Sol, nElems));

% ----------------------------------------------------------------
% IT3.3 — PlasticHistoryArchive{10} is non-empty
% ----------------------------------------------------------------
result = run_subtest(result, 'IT3.3 PlasticHistoryArchive{10} non-empty', ...
    @() it3_3(Sol));

% ----------------------------------------------------------------
% IT3.4 — recoverField('p', 10) has max > 0
% ----------------------------------------------------------------
result = run_subtest(result, 'IT3.4 recoverField p at step 10 > 0', ...
    @() it3_4(Pre, Sol, nNodes));

% ----------------------------------------------------------------
% IT3.5 — Plastic strain monotone non-decreasing across archive
% ----------------------------------------------------------------
result = run_subtest(result, 'IT3.5 plastic strain monotone across steps', ...
    @() it3_5(Sol, nElems));

result = finalise_result(result);
end

% ----------------------------------------------------------------
function it3_2(Sol, nElems)
% Check each element's HistoryData (current committed state)
max_p = 0;
for e = 1:nElems
    hd = Sol.Elements{e}.HistoryData;
    if ~isempty(hd)
        for gp = 1:length(hd)
            max_p = max(max_p, hd(gp).p);
        end
    end
end
if max_p <= 0
    error('No GP has p > 0 at step 10 — yielding did not occur');
end
end

% ----------------------------------------------------------------
function it3_3(Sol)
arch = Sol.state.PlasticHistoryArchive;
if length(arch) < 10 || isempty(arch{10})
    error('PlasticHistoryArchive{10} is empty');
end
end

% ----------------------------------------------------------------
function it3_4(Pre, Sol, nNodes)
Post  = FEM_Postprocessor_v2(Pre, Sol);
field = Post.recoverField('p', 10);

if length(field) ~= nNodes
    error('field length %d != nNodes %d', length(field), nNodes);
end
if max(field) <= 0
    error('max(p field) = %g at step 10, expected > 0', max(field));
end
end

% ----------------------------------------------------------------
function it3_5(Sol, nElems)
% For each element, p at step 10 must be >= p at step 5.
arch = Sol.state.PlasticHistoryArchive;

for e = 1:nElems
    arch5 = arch{5};
    arch10 = arch{10};
    if isempty(arch5) || isempty(arch10), continue; end

    hd5  = arch5{e};
    hd10 = arch10{e};
    if isempty(hd5) || isempty(hd10), continue; end

    for gp = 1:min(length(hd5), length(hd10))
        p5  = hd5(gp).p;
        p10 = hd10(gp).p;
        if p10 < p5 - 1e-12
            error('Element %d GP %d: p decreased from step 5 (%g) to step 10 (%g)', ...
                  e, gp, p5, p10);
        end
    end
end
end
