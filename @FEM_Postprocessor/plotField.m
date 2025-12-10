function plotField(obj, fieldType, opts)
% fieldType: 'SigmaX', 'SigmaY', 'TauXY', 'VonMises', 'PlasticStrain', 'Displacement'
% layer: 'Top', 'Mid', 'Bot' (ignored for Displacement)
if isempty(opts)
    layer='Mid';
    % scale=1.0;
else
    layer=opts.layer;
    % scale=opts.scale;
end
fprintf('[Post] recovering %s at %s layer...\n', fieldType, layer);
% 1. Recover Nodal Values (Smoothing)
switch fieldType
    case 'Displacement'
        values = sqrt(sum(obj.Solver.U(1:6:end).^2 + obj.Solver.U(2:6:end).^2 + obj.Solver.U(3:6:end).^2, 2));
        % obj.renderPlot(values,fieldType,layer,scale);
    case 'Buckling'
        U=obj.Solver.ModeShapes(:,opts.Nummode);
        values = sqrt(sum(U(1:6:end).^2 + U(2:6:end).^2 + U(3:6:end).^2, 2));
        % obj.renderPlot(values,fieldType,layer,scale);
    otherwise
        values = obj.recoverNodalSmooth(fieldType, layer);
        % obj.renderPlot(values,fieldType,layer,scale);
end

% 2. Plotting
 obj.renderPlot(values,fieldType,opts);
end