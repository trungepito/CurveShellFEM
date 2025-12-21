
function [a,b]=test1()
if nargout==1
    a = []; % Assign a default value to a
    b = 1; % Initialize b as an empty array
else
    a = 1; % Assign a value to a when two outputs are requested
    b = 1; % Set b to an empty array
end
end

[c,b]=test1()

