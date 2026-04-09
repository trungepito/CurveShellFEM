function saveSnapshot(obj, Pre, Sol, opts)
% SAVESNAPSHOT  Full project snapshot (replaces old saveState).
% Writes preprocessor + current solver state to a single MAT.
% This is the "safe export" path for hand-off / archiving.
% For incremental live saving during solve, use attachToSolver().
%
% opts (optional struct):
%   .saveMesh    (true)  include mesh and material
%   .saveBCs     (true)  include BCs and loads
%   .saveResults (true)  include U, BucklingFactors
%   .saveHistory (false) include plastic GP history (large)
if nargin < 4, opts = struct(); end
if ~isfield(opts,'saveMesh'),    opts.saveMesh    = true;  end
if ~isfield(opts,'saveBCs'),     opts.saveBCs     = true;  end
if ~isfield(opts,'saveResults'), opts.saveResults = true;  end
if ~isfield(opts,'saveHistory'), opts.saveHistory = false; end

fprintf('[DataMgr] Writing snapshot for project "%s"...\n', ...
    obj.ProjectName);

if strcmp(obj.Format, 'MAT')
    obj.saveToMAT(Pre, Sol, opts);
else
    obj.saveToCSV(Pre, Sol, opts);
end
end
