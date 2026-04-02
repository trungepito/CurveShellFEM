function isValid = validatePreprocessorOutput(Pre)
% VALIDATEPREPROCESSOROUTPUT Checks the Preprocessor output for schema consistency
% Call this before initiating solver to prevent low-level numerical crashes.

fprintf('[DataManager] Validating Preprocessor Schema...\n');
isValid = true;

% 1. Coordinates Validation
if ~isa(Pre.Mesh.Nodes, 'double') || size(Pre.Mesh.Nodes, 2) ~= 3
    error('Schema Error: Mesh.Nodes must be an N x 3 double array.');
end
if any(isnan(Pre.Mesh.Nodes(:))) || any(isinf(Pre.Mesh.Nodes(:)))
    error('Schema Error: Mesh.Nodes contains NaN or Inf.');
end

% 2. Elements Validation
if size(Pre.Mesh.Elements, 2) ~= 8
    error('Schema Error: Mesh.Elements connectivity must be N x 8 for serendipity shells.');
end

% 3. BC Table Validation
if ~isempty(Pre.BCs)
    expectedVars = {'Node', 'DOF', 'Value', 'Tag'};
    if ~isequal(Pre.BCs.Properties.VariableNames, expectedVars)
        error('Schema Error: Pre.BCs table must have columns {Node, DOF, Value, Tag}.');
    end

    % Check for conflicting duplicates
    node_dof = [Pre.BCs.Node, Pre.BCs.DOF];
    if size(unique(node_dof, 'rows'), 1) < size(node_dof, 1)
        error('Schema Error: Duplicated (Node, DOF) constraints found in Pre.BCs. Conflict imminent.');
    end
end

% 4. Loads Table Validation
if ~isempty(Pre.Loads)
    expectedVars = {'Node', 'DOF', 'Value', 'Tag'};
    if ~isequal(Pre.Loads.Properties.VariableNames, expectedVars)
        error('Schema Error: Pre.Loads table must have columns {Node, DOF, Value, Tag}.');
    end
end

fprintf(' -> Schema validation passed. Data is immutable for Solver consumption.\n');
end
