function gpScalars = extractGPScalar(obj, gpCell, fieldName) %#ok<INUSL>
% EXTRACTGPSCALAR  Map a fieldName string to a [20x1] scalar per element.
%
% This is the single place that translates the public fieldName API into
% accesses on the gpData struct.  Adding a new field requires only a new
% case here.
%
% Input:
%   gpCell     {nElems x 1} cell of [20x1] gpData struct arrays
%   fieldName  string
%
% Output:
%   gpScalars  {nElems x 1} cell, each entry a [20x1] double vector

nElems    = length(gpCell);
gpScalars = cell(nElems, 1);

for e = 1:nElems
    gp   = gpCell{e};        % [20x1] struct
    vals = zeros(20, 1);

    switch lower(fieldName)

        case 'von_mises'
            for k = 1:20, vals(k) = gp(k).von_mises; end

        case 'sigma_x'
            for k = 1:20, vals(k) = gp(k).sigma(1); end

        case 'sigma_y'
            for k = 1:20, vals(k) = gp(k).sigma(2); end

        case 'tau_xy'
            for k = 1:20, vals(k) = gp(k).sigma(3); end

        case 'sigma_1'
            for k = 1:20, vals(k) = gp(k).sigma_principal(1); end

        case 'sigma_2'
            for k = 1:20, vals(k) = gp(k).sigma_principal(2); end

        case 'eps_p_x'
            for k = 1:20, vals(k) = gp(k).eps_p(1); end

        case 'eps_p_y'
            for k = 1:20, vals(k) = gp(k).eps_p(2); end

        case 'p'
            % Equivalent plastic strain
            for k = 1:20, vals(k) = gp(k).p; end

        case 'yield_depth'
            % Fraction of through-thickness layers that have yielded.
            % Returns a single value per element repeated across all 20 GPs
            % (used for contour plotting, not SPR fitting).
            % 5 layers per in-plane GP → check each 5-block independently.
            for iGP = 1:4
                block  = (iGP-1)*5 + (1:5);
                nyield = sum([gp(block).yielded]);
                frac   = nyield / 5;
                vals(block) = frac;
            end

        case {'eps_total_x', 'strain_x'}
            for k = 1:20, vals(k) = gp(k).eps_total(1); end

        case {'eps_total_y', 'strain_y'}
            for k = 1:20, vals(k) = gp(k).eps_total(2); end

        case {'gamma_xy', 'shear_strain'}
            for k = 1:20, vals(k) = gp(k).eps_total(3); end

        otherwise
            error('FEM_Postprocessor:unknownField', ...
                'Unknown field name ''%s''. Supported: von_mises, sigma_x, sigma_y, tau_xy, sigma_1, sigma_2, p, eps_p_x, yield_depth, strain_x, strain_y.', ...
                fieldName);
    end

    gpScalars{e} = vals;
end
end
