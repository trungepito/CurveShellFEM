function F_glob = calculateGlobalTargetForce(obj, activeTags)
nDofs = length(obj.U);
F_glob = zeros(nDofs, 1);
for i = 1:length(activeTags)
    tag = activeTags{i};
    rows = strcmp(obj.Model.Loads.Tag, tag);
    data = obj.Model.Loads(rows, :);
    if ~isempty(data)
        if isnumeric(data.Node)
            idx = (data.Node-1)*6 + data.DOF;
            % Accumulate in case multiple tags hit same DOF
            F_glob = F_glob + accumarray(idx, data.Value, [nDofs 1]);
        elseif iscell(data.Node)
            idx = (cell2mat(data.Node)-1)*6 + cell2mat(data.DOF);
            F_glob = F_glob + accumarray(idx, cell2mat(data.Value), [nDofs 1]);
        end
    end
end
end