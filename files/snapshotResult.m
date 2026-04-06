function result = snapshotResult(obj)
% SNAPSHOTRESULT  Package the current solver state into an immutable SolverResult.
%
% Called at the end of every solve() method so callers can pass a
% self-contained value to FEM_Postprocessor without retaining a live
% reference to the solver.
%
% Usage (inside FEM_Solver_Adaptive.solve and FEM_Solver_ArcLength.solve):
%
%   result = obj.snapshotResult();
%
% The returned SolverResult is a value-class copy: subsequent solve()
% calls on obj do NOT affect any already-issued SolverResult.
%
% See also: SolverResult, FEM_Postprocessor

result = SolverResult(obj);
end
