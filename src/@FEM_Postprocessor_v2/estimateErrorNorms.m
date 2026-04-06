function [errEl, totalNorm] = estimateErrorNorms(obj, stepIdx)
% ESTIMATEERRORNORMS  Zienkiewicz-Zhu error estimator.
%
% Computes the energy-norm error by comparing the SPR-smoothed stress field
% (superconvergent, higher accuracy) against the raw Gauss-point stress field
% (directly from integration, lower accuracy).
%
% The element error indicator is:
%
%   eta_e^2 = integral_Omega_e  (sigma* - sigma_h)^T D^{-1} (sigma* - sigma_h) dA
%
% approximated as:
%
%   eta_e  = sqrt( (1/nGP_e) * sum_GP ||sigma*_GP - sigma_h_GP||^2 / ||sigma*_GP||^2 )
%
% where sigma* is the SPR nodal field interpolated to the GP position and
% sigma_h is the raw GP stress.  This relative form is dimensionless and
% mesh-size invariant.
%
% The global norm is the L2-averaged element error:
%   totalNorm = sqrt( sum(Area_e * eta_e^2) / sum(Area_e) )
%
% Input:
%   stepIdx  (optional) step index; defaults to current step
%
% Output:
%   errEl      [nElems x 1] element-wise relative error indicator (0–1 scale)
%   totalNorm  scalar global relative error norm

if nargin < 2 || isempty(stepIdx)
    stepIdx = obj.Solver.StepCount;
end

fprintf('[Postprocessor] Running ZZ error estimation at step %d ...\n', stepIdx);

% ── Stage 1: GP recovery ────────────────────────────────────────
gpCell = obj.recoverAllGaussPoints(stepIdx);

% ── Stage 2: SPR on Von Mises (representative stress norm) ──────
nodalVM = obj.recoverNodalSPR(gpCell, 'von_mises');

% ── Element loop ────────────────────────────────────────────────
Nodes    = obj.Model.Mesh.Nodes;
Elements = double(obj.Model.Mesh.Elements);
nElems   = size(Elements, 1);

errEl  = zeros(nElems, 1);
areaEl = zeros(nElems, 1);

sqrt3_inv = 1 / sqrt(3);
gp_xi_in  = [-sqrt3_inv, -sqrt3_inv,  sqrt3_inv,  sqrt3_inv];
gp_eta_in = [-sqrt3_inv,  sqrt3_inv, -sqrt3_inv,  sqrt3_inv];

for e = 1:nElems
    nIdx     = Elements(e, :);
    elCoords = Nodes(nIdx, :);
    gp       = gpCell{e};

    % Approximate element area from Jacobians at 4 in-plane GPs
    area_e = 0;
    sumSqErr  = 0;
    sumSqRef  = 0;

    for iGP = 1:4
        xi  = gp_xi_in(iGP);
        eta = gp_eta_in(iGP);

        % Jacobian determinant for area weight
        elObj = obj.Solver.Elements{e};
        [detJ, ~, ~, ~] = elObj.calculateKinematics(xi, eta);
        area_e = area_e + detJ;  % weight 1×1 = 1 for 2×2 Gauss

        % Raw GP Von Mises (mid-layer, zeta=0, layer 3)
        pt_mid   = (iGP - 1)*5 + 3;
        vm_raw   = gp(pt_mid).von_mises;

        % SPR-interpolated Von Mises at this GP position
        [N, ~]   = Curve8Element.fmisoq8(xi, eta);
        nodalVM_el = nodalVM(nIdx);          % [8x1] nodal values
        vm_spr   = N * nodalVM_el(:);        % scalar

        diff2    = (vm_spr - vm_raw)^2;
        ref2     = vm_spr^2;
        sumSqErr = sumSqErr + diff2;
        sumSqRef = sumSqRef + max(ref2, 1e-30);  % avoid /0 in stress-free zones
    end

    areaEl(e)  = area_e;
    errEl(e)   = sqrt(sumSqErr / max(sumSqRef, 1e-30));
end

% Global energy-norm error (area-weighted RMS)
totalNorm = sqrt(sum(areaEl .* errEl.^2) / max(sum(areaEl), 1e-30));

fprintf('[Postprocessor] ZZ error: global norm = %.4f  (max element = %.4f)\n', ...
    totalNorm, max(errEl));
end
