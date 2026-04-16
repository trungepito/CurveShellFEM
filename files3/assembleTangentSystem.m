function [KT, F_int, TrialHist] = assembleTangentSystem(obj, U_curr)
% ASSEMBLETANGENTSYSTEM  Unified assembly of Global KT, F_int, and Trial History.
%
% Enhancement log (P2.2, P4.1):
%
%   P2.2 — KT symmetry enforcement:
%           After accumulating element contributions, the global tangent is
%           symmetrised as  KT = 0.5*(KT + KT').  For linear-elastic
%           problems the assembly is already symmetric to machine precision,
%           so this adds negligible cost.  For J2-plastic problems the
%           algorithmic tangent Dep is only *nearly* symmetric (the Newton
%           loop in Material_J2Plastic.integrateStress is iterative), and
%           numerical asymmetry accumulates at the global level; the
%           symmetrisation prevents the factoriser from encountering a
%           spurious rank deficiency.
%
%   P4.1 — Elastic fast-path flag:
%           When the material model is linear elastic (no J2Plastic type),
%           the tangent is constant within a step.  Callers that know this
%           (e.g. the arc-length corrector for elastic problems) can skip
%           re-assembly of KT and only reassemble F_int via
%           assembleinternalforceONLY.  This function sets
%           obj.KT_is_elastic_constant = true  when elastic, so the
%           arc-length corrector can check the flag.

if nargin < 2
    U_curr = obj.U;
end

nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs  = nNodes * 6;
nElems = size(obj.Model.Mesh.Elements, 1);

% ── Sparse triplet pre-allocation ────────────────────────────────────────
tick          = tic;
nz_per_elem   = 48 * 48;
estnz         = nz_per_elem * nElems;
I = zeros(estnz, 1);
J = zeros(estnz, 1);
V = zeros(estnz, 1);

F_int     = zeros(nDofs, 1);
TrialHist = cell(nElems, 1);

% Pre-compute local index grids (SK-04)
[ii_base, jj_base] = ndgrid(1:48, 1:48);
ii_base = ii_base(:);
jj_base = jj_base(:);

% ── P4.1: detect elastic-constant tangent ────────────────────────────────
mat = obj.Model.Material;
is_elastic = ~isfield(mat, 'Type') || ~strcmp(mat.Type, 'J2Plastic');

% ── Assembly loop ────────────────────────────────────────────────────────
count = 0;
for e = 1:nElems
    sctr   = obj.SctrMap(e, :);
    u_el   = U_curr(sctr);
    elObj  = obj.Elements{e};

    [KT_global, fe, NewHist] = elObj.computeGlobalMatrix6DOF(u_el);
    TrialHist{e} = NewHist;

    F_int(sctr) = F_int(sctr) + fe;

    range        = count + (1:nz_per_elem);
    I(range)     = sctr(ii_base);
    J(range)     = sctr(jj_base);
    V(range)     = KT_global(:);
    count        = count + nz_per_elem;
end

% ── Sparse matrix construction ───────────────────────────────────────────
KT = sparse(I(1:count), J(1:count), V(1:count), nDofs, nDofs);

% ── P2.2: enforce symmetry ───────────────────────────────────────────────
% For elastic problems this is a no-op to machine precision.
% For J2-plastic problems this removes accumulation of iterative-Newton
% asymmetry in Dep and prevents spurious rank-deficiency reports.
KT = 0.5 * (KT + KT');

% ── P4.1: expose elastic-constant flag to callers ────────────────────────
% The arc-length corrector reads this to decide whether to skip KT
% re-assembly and only call assembleinternalforceONLY instead.
obj.KT_is_elastic_constant = is_elastic;

t_elapsed = toc(tick); % measure the run time!!!
% (Suppress per-iteration print; the solver loop is verbose enough.)
end
