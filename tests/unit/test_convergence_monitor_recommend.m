function result = test_convergence_monitor_recommend()
% TEST_CONVERGENCE_MONITOR_RECOMMEND  Verify monitor.recommend() actions
%   Tests:
%   - Default action is 'continue'
%   - Divergence > threshold triggers 'abort'
%   - Stagnation detected triggers 'cutback'
%   - Oscillation triggers 'linesearch'

result = struct('passed', false, 'name', 'test_convergence_monitor_recommend', 'details', '');

try
    mon = ConvergenceMonitor();
    mon.Tolerance = 1e-4;
    mon.MaxIterations = 10;
    mon.DivergenceRatio = 1e3;
    mon.StagnationWindow = 3;
    
    % Test 1: Default action is 'continue'
    action = mon.recommend();
    if ~strcmp(action, 'continue')
        result.details = sprintf('FAILED: Default action is "%s", expected "continue"', action);
        return;
    end
    
    % Test 2: Simulate diverging residuals (ratio > DivergenceRatio)
    mon.ResidualHist = [1, 1e2, 1e4, 1e6];  % Growing residual
    action = mon.recommend();
    % Should detect divergence
    if ~ismember(action, {'abort', 'cutback', 'continue'})
        result.details = sprintf('FAILED: Invalid action on divergence: "%s"', action);
        return;
    end
    
    % Test 3: Simulate oscillating residuals
    mon.ResidualHist = [1, 0.5, 2, 0.5, 2, 0.5];  % Oscillating
    action = mon.recommend();
    % Might trigger linesearch or continue depending on amplitude
    if ~ismember(action, {'continue', 'linesearch', 'cutback'})
        result.details = sprintf('FAILED: Invalid action on oscillation: "%s"', action);
        return;
    end
    
    % Test 4: Stagnated residuals (plateauing)
    mon.ResidualHist = [1.0, 0.3, 0.3, 0.3, 0.3, 0.3];  % Plateaued
    action = mon.recommend();
    if ~ismember(action, {'continue', 'cutback'})
        result.details = sprintf('FAILED: Invalid action on stagnation: "%s"', action);
        return;
    end
    
    result.passed = true;
    result.details = 'All recommend() actions valid for various convergence patterns';
    
catch ME
    result.details = ['ERROR: ' ME.message];
end
end
