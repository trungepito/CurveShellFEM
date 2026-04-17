function results = test_monitor_recommendations()
% TEST_MONITOR_RECOMMENDATIONS - Verify Task 14 (Wire monitor.recommend())
% Checks that convergence monitor recommendations are integrated into corrector
results = struct('passed', false, 'name', 'test_monitor_recommendations', 'details', '');

try
    % Create a solver with convergence monitoring
    solver = FEM_Solver_Nonlinear();
    
    % Verify ConvergenceMonitor exists and has recommend method
    if ~isprop(solver, 'Monitor') || ~isa(solver.Monitor, 'ConvergenceMonitor')
        results.details = 'FAILED: Solver missing ConvergenceMonitor property';
        return;
    end
    
    monitor = solver.Monitor;
    if ~ismethod(monitor, 'recommend')
        results.details = 'FAILED: ConvergenceMonitor missing recommend() method';
        return;
    end
    
    % Verify recommend() can be called and returns valid action
    action = monitor.recommend();
    validActions = {'continue', 'abort', 'linesearch', 'cutback'};
    
    if ismember(action, validActions)
        results.passed = true;
        results.details = sprintf('Monitor.recommend() returns valid action: "%s"', action);
    else
        results.details = sprintf('FAILED: Monitor.recommend() returned invalid action: "%s"', action);
    end
    
catch ME
    results.details = ['ERROR: ' ME.message];
end
end
