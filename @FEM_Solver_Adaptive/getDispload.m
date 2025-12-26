function [fixed_dofs,targets]=getDispload(obj,ActiveBCs)
% 2. PROCESS BCs BY TAG
if isempty(ActiveBCs)
    warning('Please check the boundary condition!!! No support is found')
end
fixed_dofs=[];
targets=[];
for i = 1:length(ActiveBCs)
    tag = ActiveBCs{i};
    rows = strcmp(obj.Model.BCs.Tag, tag);
    data = obj.Model.BCs(rows, :);
    if ~isempty(data)
        indices = (data.Node - 1)*6 + data.DOF;
        fixed_dofs = [fixed_dofs; indices];
        % Ramp: StartDisp -> Target
        targets = [targets;data.Value];
    end
end