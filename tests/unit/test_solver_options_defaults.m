function result = test_solver_options_defaults()
% TEST_SOLVER_OPTIONS_DEFAULTS  Verify default SolverOptions are sensible

result = struct('passed', false, 'name', 'test_solver_options_defaults', 'details', '');

try
    opts = SolverOptions();
    
    % Verify critical defaults are set
    assert(opts.MaxIterations == 25, 'MaxIterations should default to 25');
    assert(opts.TolForce == 1e-4, 'TolForce should default to 1e-4');
    assert(opts.TolDisp == 1e-3, 'TolDisp should default to 1e-3');
    assert(opts.LBFGSHistory == 6, 'LBFGSHistory should default to 6');
    assert(opts.MinDt == 1e-3, 'MinDt should default to 1e-3');
    assert(opts.MaxDt == 1.0, 'MaxDt should default to 1.0');
    
    % Verify defaults can pass validation
    opts.validate();
    
    result.passed = true;
    result.details = 'All default SolverOptions are valid and reasonable';
    
catch ME
    result.details = ['ERROR: ' ME.message];
end
end
