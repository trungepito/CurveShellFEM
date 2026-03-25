function addBC(obj, nodes, dofs, value, tag)
% ADDBC Apply Boundary Conditions
% Usage: obj.addBC(nodes, dofs, value, tag)
%   nodes: Array of node IDs
%   dofs: Array of DOF indices (1-6)
%   value: Scalar displacement value
%   tag: Optional string tag for the BC (default: 'Support')

if nargin < 5 || isempty(tag), tag = 'Support'; end

% Ensure nodes and dofs are row vectors for the loop
nodes = nodes(:)';
dofs = dofs(:)';

% Pre-create arrays for bulk table creation
numNew = length(nodes) * length(dofs);
newNodes = zeros(numNew, 1);
newDofs = zeros(numNew, 1);
newVals = zeros(numNew, 1);
newTags = cell(numNew, 1);

curr = 1;
for i = nodes
    for j = dofs
        newNodes(curr) = i;
        newDofs(curr) = j;
        newVals(curr) = value; % Assumes scalar value for all selected DOFs
        newTags{curr} = tag;
        curr = curr + 1;
    end
end

% Create and append the new table
newTable = table(newNodes, newDofs, newVals, newTags, 'VariableNames', {'Node','DOF','Value','Tag'});
obj.BCs = [obj.BCs; newTable];

fprintf('[Physics] BC added to %d nodes (%d total entries).\n', length(nodes), numNew);
end
