function plotPlasticYield(obj, opts)
% PLOTPLASTICYIELD - Renders the through-thickness yielded fraction.
% Fraction = 0: Elastic
% Fraction = 1: Fully yielded across thickness.

if nargin < 2, opts = struct(); end

% 1. Get Nodal Yield Fractions
values = obj.recoverPlasticFront();

% 2. Check for zero plasticity
if max(values) < 1e-12
    warning('FEM_Postprocessor:noPlasticity', 'No plastic deformation detected in the model.');
end

% 3. Set Plot Options
fieldType = 'Plastic Yield Fraction';
if ~isfield(opts, 'colormap'), opts.colormap = 'hot'; end
if ~isfield(opts, 'title'),    opts.title = 'Through-Thickness Plastic Yield Front'; end

% 4. Delegate to renderPlot
obj.renderPlot(values, fieldType, opts);

% 5. Add custom annotation
title(opts.title, 'FontSize', 14);
cb = colorbar;
ylabel(cb, 'Yielded Fraction (0-1)');

end
