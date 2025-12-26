function addBC(obj, nodes, dofs,value, tag)
% General BC Manager
% method: 'nodeList', 'box', 'plane'
% selection: depends on method (IDs, or Box coords, or Plane coords)
for i = 1:length(nodes)
        for j = 1:length(dofs)
            newRow = {nodes(i), dofs(j), value, tag};
            obj.BCs = [obj.BCs; newRow];
        end
end
fprintf('[Physics] BC added to %d nodes.\n', length(nodes));
end

% if isempty(varargin)
%     val_dis=0;
% else
%     val_dis = varargin{1}; % Assign the first optional argument to val_dis  
% end
% nodeIDs = [];
% switch method
%     case 'nodeList'
%         nodeIDs = selection;
%     case 'box'
%         nodeIDs = obj.selectNodesByBox(selection(1), selection(2), selection(3), ...
%             selection(4), selection(5), selection(6));
%     case 'plane'
%         % selection = [dim, val]
%         nodeIDs = obj.selectNodesOnPlane(selection(1), selection(2));
% end
% 
% % Apply
% for i = 1:length(nodeIDs)
%     for d = dofs
%         obj.BCs = [obj.BCs; nodeIDs(i), d,val_dis];
%     end
% end
% 
% fprintf('[Physics] BC added to %d nodes.\n', length(nodeIDs));
% end
