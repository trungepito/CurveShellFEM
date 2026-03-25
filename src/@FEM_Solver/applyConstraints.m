function applyConstraints(obj)
% applyConstraints: Identifies Free and Constrained DOFs
% Uses partitioning method for v3.0 robustness

nDofs = size(obj.Model.Mesh.Nodes, 1) * 6;

if isempty(obj.Model.BCs)
    obj.FreeDofs = 1:nDofs;
    return;
end

if istable(obj.Model.BCs)
    % Modern Table format (Node, DOF, Value, Tag)
    fixed_dofs = (obj.Model.BCs.Node-1)*6 + obj.Model.BCs.DOF;
else
    % Matrix form [Node, DOF]
    fixed_dofs = (obj.Model.BCs(:,1)-1)*6 + obj.Model.BCs(:,2);
end

unique_fixed = unique(fixed_dofs);
obj.FreeDofs = setdiff(1:nDofs, unique_fixed);

fprintf('[Solver] Constraints Applied. Free DOFs: %d/%d\n', length(obj.FreeDofs), nDofs);

end