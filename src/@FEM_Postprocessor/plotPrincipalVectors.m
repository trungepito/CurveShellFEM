function plotPrincipalVectors(obj, layer)
% Calculates Principal Stresses and plots arrows
nodes = obj.Model.Mesh.Nodes;
hold on;
for i = 1:size(nodes, 1)
    % Get SigmaX, SigmaY, TauXY at this node (smoothed)
    sx = obj.recoverNodalSmooth('SigmaX', layer);
    sy = obj.recoverNodalSmooth('SigmaY', layer);
    txy = obj.recoverNodalSmooth('TauXY', layer);

    sig_vec = [sx(i), sy(i), txy(i)];

    % Eigenvalues of [sx txy; txy sy]
    % Calculate angle theta
    theta = 0.5 * atan2(2*sig_vec(3), sig_vec(1)-sig_vec(2));

    % Plot Max Principal direction
    v1 = [cos(theta), sin(theta), 0];
    % Scale arrow by magnitude
    quiver3(nodes(i,1), nodes(i,2), nodes(i,3), v1(1), v1(2), v1(3), 'k');
end
end