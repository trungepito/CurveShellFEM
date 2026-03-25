function addNodalLoad(obj, nodes, dofs, value, tag)
% addNodalLoad: Robustly adds nodal loads to the preprocessor
if nargin < 5, tag = 'LOAD'; end

for i = 1:length(nodes)
    for j = 1:length(dofs)
        % Ensure numeric types for the table
        newRow = table(double(nodes(i)), double(dofs(j)), double(value), {tag}, ...
            'VariableNames', {'Node', 'DOF', 'Value', 'Tag'});
        if isempty(obj.Loads)
            obj.Loads = newRow;
        else
            obj.Loads = [obj.Loads; newRow];
        end
    end
end
end