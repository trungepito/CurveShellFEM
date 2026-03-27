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

% Create a grid of all node and DOF combinations
[N_grid, D_grid] = ndgrid(double(nodes), double(dofs));

newNodes = N_grid(:);
newDofs = D_grid(:);
numNew = length(newNodes);

newVals = repmat(double(value), numNew, 1);
newTags = repmat({tag}, numNew, 1);

% Create and append the new table
newTable = table(newNodes, newDofs, newVals, newTags, 'VariableNames', {'Node','DOF','Value','Tag'});

if isempty(obj.BCs)
    obj.BCs = newTable;
else
    obj.BCs = [obj.BCs; newTable];
end

fprintf('[Physics] BC added to %d nodes (%d total entries).\n', length(nodes), numNew);
end
