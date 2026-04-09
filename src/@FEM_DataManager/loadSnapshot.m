function [Pre, Sol] = loadSnapshot(obj)
% LOADSNAPSHOT  Reconstruct Pre and Sol from a full snapshot MAT.
% Replaces old loadState().
[Pre, Sol] = obj.loadState();
end
