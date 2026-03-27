function F_glob = calculateGlobalTargetForce(obj, activeTags)
    % CALCULATEGLOBALTARGETFORCE - Extracts nodal forces from Preprocessor.
    F_glob = zeros(size(obj.U));
    if isempty(activeTags), return; end
    
    Loads = obj.Model.Loads;
    if iscell(Loads.Node), Nodes = cell2mat(Loads.Node); else, Nodes = double(Loads.Node); end
    if iscell(Loads.DOF), DOFs = cell2mat(Loads.DOF); else, DOFs = double(Loads.DOF); end
    if iscell(Loads.Value), Values = cell2mat(Loads.Value); else, Values = double(Loads.Value); end
    Tags = Loads.Tag;
    
    for i = 1:size(Loads, 1)
        if any(strcmp(Tags{i}, activeTags))
            idx = (Nodes(i)-1)*6 + DOFs(i);
            F_glob(idx) = F_glob(idx) + Values(i);
        end
    end
end
