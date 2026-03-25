function plotField(obj, fieldType, opts)
% PLOTFIELD Main entry point for visualizing FEA results
% fieldType: 'SigmaX', 'SigmaY', 'TauXY', 'VonMises', 'PrincipalStress1', 'PrincipalStress2', 'Pressure', 'PlasticStrain', 'Displacement', 'Buckling'
% opts: (Optional) Struct with .layer, .scale, .Nummode

if nargin < 3 || isempty(opts)
    opts = struct('layer', 'Mid', 'scale', 1.0);
end

% Standardize options
if ~isfield(opts, 'layer'), opts.layer = 'Mid'; end
if ~isfield(opts, 'scale'), opts.scale = 1.0; end

layer = opts.layer;
fprintf('[Post] recovering %s at %s layer...\n', fieldType, layer);

% 1. Recover Nodal Values (Smoothing)
switch fieldType
    case 'Displacement'
        % Node-wise magnitude across all 3 translation DOFs
        U = obj.Solver.U;
        values = sqrt(sum(U(1:6:end).^2 + U(2:6:end).^2 + U(3:6:end).^2, 2));
    case 'UX'
        % Node-wise magnitude across all 3 translation DOFs
        U = obj.Solver.U;
        values = U(1:6:end);
    case 'UY'
        % Node-wise magnitude across all 3 translation DOFs
        U = obj.Solver.U;
        values = U(2:6:end);
    case 'UZ'
        % Node-wise magnitude across all 3 translation DOFs
        U = obj.Solver.U;
        values = U(3:6:end);


    case 'Buckling'
        % Visualize Mode Shape
        if ~isfield(opts, 'Nummode'), opts.Nummode = 1; end
        U = obj.Solver.ModeShapes(:, opts.Nummode);
        values = sqrt(sum(U(1:6:end).^2 + U(2:6:end).^2 + U(3:6:end).^2, 2));

    case 'PlasticFront'
        % Visualization of yield penetration through thickness
        values = obj.recoverPlasticFront();

    otherwise
        % Recovery for Stress/Strain/Plasticity
        % Use SPR for higher accuracy if requested, otherwise NodalSmooth
        if isfield(opts, 'UseSPR') && opts.UseSPR
            values = obj.recoverSPR(fieldType, layer);
        else
            values = obj.recoverNodalSmooth(fieldType, layer);
        end
end

% 2. Delegate to Rendering Engine
obj.renderPlot(values, fieldType, opts);
end