function tf = hasArchive(obj, stepIdx)
% HASARCHIVE  Check if plastic archive exists for a requested step.
%
% Prevents silent fallbacks when reconstructing past states.
% Returns false if the step is out of bounds or archive is missing.
%
% Usage:
%   if Post.hasArchive(5)
%       gp = Post.recoverAllGaussPoints(5);  % archive guaranteed
%   else
%       warning('No archive for step 5');
%   end

tf = false;

% Boundary check
if isempty(stepIdx) || stepIdx <= 0 || stepIdx > obj.Snapshot.StepCount
    return;
end

% Archive check
if isempty(obj.Snapshot.PlasticHistoryArchive) || ...
   length(obj.Snapshot.PlasticHistoryArchive) < stepIdx
    return;
end

% Element check: archive is valid only if all elements have data
archive_step = obj.Snapshot.PlasticHistoryArchive{stepIdx};
if isempty(archive_step)
    return;
end

nElems = length(obj.Elements);
if length(archive_step) ~= nElems
    return;
end

% All checks passed
tf = true;

end
