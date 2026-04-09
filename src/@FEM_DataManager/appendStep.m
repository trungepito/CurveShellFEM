function appendStep(obj, stageIdx, stepData)
% APPENDSTEP  Manually append one converged step to disk.
% stepData struct fields:
%   .U         [nDofs x 1] displacement
%   .lambda    scalar load factor
%   .iters     integer iteration count
%   .arc_used  scalar arc-length radius that converged
%   .time      pseudo-time value
%   .GPHistory cell {nElems x 1} of HistoryData structs (optional)
obj.writeStep_(stageIdx, stepData);
end
