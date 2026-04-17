function field = recoverField(obj, fieldName, stepIdx)
% RECOVERFIELD  Public entry point for any nodal field.
%
% Dispatches to the correct recovery pipeline:
%   - Displacement fields  →  read directly from U_Hist (no GP integration)
%   - Stress/strain fields →  Stage 1 (GP recovery) + Stage 2 (SPR)
%
% Input:
%   fieldName  string — see FEM_Postprocessor_v2 class header for full list
%   stepIdx    integer (1-based column of U_Hist) or [] for current step
%
% Output:
%   field  [nNodes x 1] smoothed nodal values

if nargin < 3 || isempty(stepIdx)
    stepIdx = obj.Snapshot.StepCount;
end

% ---------------------------------------------------------------
% Route by field family
% ---------------------------------------------------------------
switch lower(fieldName)

    % ── Kinematic fields: read U directly ──────────────────────
    case 'displacement_x'
        U     = obj.getDisplacementAtStep(stepIdx);
        field = U(1:6:end);
        return;
    case 'displacement_y'
        U     = obj.getDisplacementAtStep(stepIdx);
        field = U(2:6:end);
        return;
    case 'displacement_z'
        U     = obj.getDisplacementAtStep(stepIdx);
        field = U(3:6:end);
        return;
    case 'displacement_total'
        U     = obj.getDisplacementAtStep(stepIdx);
        dx    = U(1:6:end);  dy = U(2:6:end);  dz = U(3:6:end);
        field = sqrt(dx.^2 + dy.^2 + dz.^2);
        return;

    % ── Stress / strain fields: GP pipeline ────────────────────
    case {'von_mises','sigma_x','sigma_y','tau_xy', ...
          'sigma_1','sigma_2','eps_p_x','eps_p_y','p', ...
          'yield_depth','eps_total_x','eps_total_y', ...
          'strain_x','strain_y','gamma_xy','shear_strain'}

        gpCell = obj.recoverAllGaussPoints(stepIdx);

        % SPR projection with automatic fallback
        % The default is SPR methods i.e., extrapolation from Gauss point
        % using linear/.. functions
        try
            field = obj.recoverNodalSPR(gpCell, fieldName);
        catch
            warning('FEM_Postprocessor_v2:sprFailed', ...
                'SPR failed for field ''%s''. Using nodal average.', fieldName);
            field = obj.recoverNodalAverage(gpCell, fieldName);
        end
        return;

    otherwise
        error('FEM_Postprocessor_v2:unknownField', ...
            'Unknown field ''%s''. See FEM_Postprocessor_v2 class header for valid names.', ...
            fieldName);
end
end
