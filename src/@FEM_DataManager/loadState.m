function [Pre, Sol] = loadState(obj)
%LOADSTATE Compatibility wrapper for legacy API.
[Pre, Sol] = obj.loadSnapshot('project');
end
