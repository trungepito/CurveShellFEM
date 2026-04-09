function delete(obj)
% Clean up event listeners when object is destroyed
for i = 1:length(obj.Listeners_)
    if isvalid(obj.Listeners_{i})
        delete(obj.Listeners_{i});
    end
end
end
