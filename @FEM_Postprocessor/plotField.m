function plotField(obj, fieldType, layer)
% fieldType: 'SigmaX', 'SigmaY', 'TauXY', 'VonMises', 'PlasticStrain', 'Displacement'
% layer: 'Top', 'Mid', 'Bot' (ignored for Displacement)

fprintf('[Post] recovering %s at %s layer...\n', fieldType, layer);

% 1. Recover Nodal Values (Smoothing)
if strcmp(fieldType, 'Displacement')
    values = sqrt(sum(obj.Solver.U(1:5:end).^2 + obj.Solver.U(2:5:end).^2 + obj.Solver.U(3:5:end).^2, 2));
else
    values = obj.recoverNodalSmooth(fieldType, layer);
end

% 2. Plotting
obj.renderPlot(values, [fieldType ' - ' layer]);
end