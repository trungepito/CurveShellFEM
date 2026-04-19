function result = verify_plastic_thick_plate()
% VERIFY_PLASTIC_THICK_PLATE  Limit load for clamped circular plate.
%
% VT5.1  Run 20 load steps with J2 plasticity.
% VT5.2  Reference P_lim from Johansen yield-line theory.
% VT5.3  PASS: load at full plasticity within 10% of P_lim.
% VT5.4  Load-displacement curve is monotonically non-decreasing.
%
% Model: clamped circular plate under uniform pressure.
%   E = 200 GPa, nu = 0.3, sigma_Y = 250 MPa, H = 0 (perfect plasticity).
%   t = 10 mm = 0.01 m, R = 100 mm = 0.1 m.
%
% Johansen limit load (yield-line, upper-bound):
%   P_lim = 2 * pi * M_p / R^2 * (1 + R/2R) ... simplified for circle:
%   P_lim = 6 * M_p / R^2  where  M_p = sigma_Y * t^2 / 4
%   => P_lim = 6 * sigma_Y * t^2 / (4 * R^2) * ... see Johansen (1962)
%
% Using the standard result for clamped circular plate:
%   P_lim = 6 * sigma_Y * t^2 / R^2   [N/m^2 = Pa]
% (Johansen, 1962; also Chakrabarty "Theory of Plasticity" p.597)

addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'src')));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'helpers'));

result = make_result('verify_plastic_thick_plate');

result = run_subtest(result, 'VT5.1-VT5.4 plastic thick plate limit load', ...
    @() run_plastic_plate());

result = finalise_result(result);
end

% ----------------------------------------------------------------
function run_plastic_plate()
E    = 200e9;
nu   = 0.3;
sigY = 250e6;
H    = 0;        % perfect plasticity
t    = 0.01;     % m
Rp   = 0.1;      % m (plate radius)

% Johansen limit pressure [Pa]
% P_lim_pa = 6 * sigY * t^2 / Rp^2
P_lim_pa = 6 * sigY * t^2 / Rp^2;
fprintf('  [Plastic Plate] Johansen limit pressure P_lim = %.3f kPa\n', P_lim_pa/1e3);

% ----------------------------------------------------------------
% VT5.1  Build model: use a quarter-symmetric square approximation
% to a circle (clamped outer boundary, quarter model with symmetry BCs).
% The exact circle cannot be meshed with quadrilateral elements;
% use a 0.1x0.1 square approximation (close enough for limit load check).
% ----------------------------------------------------------------
L_half = Rp;   % half-side of square approximating circle

Pre = FEM_Preprocessor_v2(E, nu, t);
Pre.createPlate([0, 0, 0], L_half, L_half);
Pre.meshAllPatches(4, 4);
Pre.setMaterialPlastic(sigY, H);

nNodes = size(Pre.Mesh.Nodes, 1);
nElems = size(Pre.Mesh.Elements, 1);

% Clamped boundary on the outer two edges (x=L_half and y=L_half)
x_edge = Pre.selectNodesOnPlane(1, L_half, 1e-4);
y_edge = Pre.selectNodesOnPlane(2, L_half, 1e-4);
all_outer = union(x_edge, y_edge);
Pre.addBC(all_outer, 1:6, 0, 'Clamp');

% Symmetry BCs at x=0 and y=0
x0_nodes = Pre.selectNodesOnPlane(1, 0.0, 1e-4);
y0_nodes = Pre.selectNodesOnPlane(2, 0.0, 1e-4);
Pre.addBC(x0_nodes, [1, 5], 0, 'SymX');
Pre.addBC(y0_nodes, [2, 4], 0, 'SymY');

% Apply reference pressure 1 Pa (will be scaled by lambda)
all_elems = (1 : nElems)';
Pre.addPressureLoad(all_elems, 1.0, 'Pressure');   % 1 Pa reference

opts = SolverOptions();
opts.MaxIterations = 25;
opts.TolForce      = 1e-4;
Sol = FEM_Solver_Nonlinear(Pre, opts);

S1 = LoadingStage(1.0);
S1.ConstraintType  = 'LoadControl';
S1.ArcLengthRadius = 1/20;   % 20 equal steps
S1.activateBC('Clamp');
S1.activateBC('SymX');
S1.activateBC('SymY');
S1.activateLoad('Pressure');

Sol.solve({S1});

nSteps = Sol.StepCount;
fprintf('  [Plastic Plate] Completed %d load steps\n', nSteps);

% The applied pressure at each step = lambda * 1 Pa
% Scale by 4 (quarter model) for total load comparison
lh = Sol.LambdaHist;   % Pa (since reference is 1 Pa)

% ----------------------------------------------------------------
% VT5.3  Identify step at which full-thickness yielding occurs at centre
% ----------------------------------------------------------------
% Centre node: node at (0,0,0)
nodes = Pre.Mesh.Nodes;
[~, centre_node] = min(nodes(:,1).^2 + nodes(:,2).^2 + nodes(:,3).^2);

full_yield_step = NaN;
for s = 1:nSteps
    arch = Sol.state.PlasticHistoryArchive{s};
    if isempty(arch), continue; end

    % Find element containing centre
    elems = Pre.Mesh.Elements;
    centre_elems = [];
    for e = 1:nElems
        if any(elems(e,:) == centre_node)
            centre_elems(end+1) = e; %#ok<AGROW>
        end
    end

    if isempty(centre_elems), continue; end

    % Check if all 5 through-thickness layers have yielded in the first
    % centre element at any in-plane GP
    for ce = centre_elems
        if ~isempty(arch{ce})
            % Count yielded layers at first in-plane GP (pts 1-5)
            n_yield = sum([arch{ce}(1:5).p] > 0);
            if n_yield == 5   % all 5 layers yielded
                full_yield_step = s;
                break;
            end
        end
    end
    if ~isnan(full_yield_step), break; end
end

if isnan(full_yield_step)
    % Fallback: use max load step
    full_yield_step = nSteps;
    fprintf('  [Plastic Plate] WARNING: full-thickness yield not clearly detected; using step %d\n', nSteps);
end

P_full_yield = lh(full_yield_step);   % Pa (our 1-Pa reference load * lambda)
rel_err = abs(P_full_yield - P_lim_pa) / P_lim_pa;

fprintf('  [Plastic Plate] Full-yield pressure at step %d = %.3f kPa\n', ...
    full_yield_step, P_full_yield/1e3);
fprintf('  [Plastic Plate] P_lim (Johansen) = %.3f kPa\n', P_lim_pa/1e3);
fprintf('  [Plastic Plate] Relative error = %.2f%%  (tol 10%%)\n', rel_err * 100);

if rel_err > 0.10
    error(['PLASTIC PLATE FAILED: P_full_yield = %g Pa, P_lim = %g Pa, ' ...
           'rel error = %.2f%% > 10%%.'], P_full_yield, P_lim_pa, rel_err * 100);
end

% ----------------------------------------------------------------
% VT5.4  Load-displacement monotonicity
% ----------------------------------------------------------------
centre_uz_dof = (centre_node - 1) * 6 + 3;
uz_hist = zeros(nSteps, 1);
for s = 1:nSteps
    U = Sol.state.getU(s);
    uz_hist(s) = abs(U(centre_uz_dof));
end

for s = 2:nSteps
    if uz_hist(s) < uz_hist(s-1) - 1e-10
        error(['PLASTIC PLATE FAILED: displacement decreased at step %d ' ...
               '(load-displacement not monotone): |uz(%d)|=%g < |uz(%d)|=%g'], ...
              s, s, uz_hist(s), s-1, uz_hist(s-1));
    end
end
fprintf('  [Plastic Plate] Load-displacement curve is monotone non-decreasing.\n');
end
