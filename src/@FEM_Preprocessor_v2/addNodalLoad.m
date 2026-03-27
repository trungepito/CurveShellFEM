function addNodalLoad(obj, nodes, dofs, value, tag)
% addNodalLoad: Robustly adds nodal loads to the preprocessor (Bulk Optimized)
if nargin < 5 || isempty(tag), tag = 'LOAD'; end

nodes = nodes(:)';
dofs = dofs(:)';

numNew = length(nodes) * length(dofs);
newNodes = zeros(numNew, 1);
newDofs = zeros(numNew, 1);
newVals = zeros(numNew, 1);
newTags = cell(numNew, 1);

curr = 1;
for i = nodes
    for j = dofs
        newNodes(curr) = double(i);
        newDofs(curr) = double(j);
        newVals(curr) = double(value);
        newTags{curr} = tag;
        curr = curr + 1;
    end
end

newTable = table(newNodes, newDofs, newVals, newTags, 'VariableNames', {'Node', 'DOF', 'Value', 'Tag'});

if isempty(obj.Loads)
    obj.Loads = newTable;
else
    obj.Loads = [obj.Loads; newTable];
end

fprintf('[Physics] Nodal load added to %d nodes (%d total entries).\n', length(nodes), numNew);
end