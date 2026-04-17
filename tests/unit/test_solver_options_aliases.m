function result = test_solver_options_aliases()
% TEST_SOLVER_OPTIONS_ALIASES  Verify backward compatibility aliases work

result = struct('passed', false, 'name', 'test_solver_options_aliases', 'details', '');

try
    opts = SolverOptions();
    
    % Test Tolerance alias
    opts.Tolerance = 1e-5;
    assert(opts.TolForce == 1e-5, 'Tolerance should map to TolForce');
    
    % Test tol alias
    opts.tol = 2e-4;
    assert(opts.TolForce == 2e-4, 'tol should map to TolForce');
    
    % Test maxIter alias
    opts.maxIter = 50;
    assert(opts.MaxIterations == 50, 'maxIter should map to MaxIterations');
    
    % Test linesearch alias
    opts.linesearch = true;
    assert(opts.UseLineSearch == true, 'linesearch should map to UseLineSearch');
    
    % Test UseLBFGS alias
    opts.UseLBFGS = true;
    assert(opts.UseQuasiNewton == true, 'UseLBFGS should map to UseQuasiNewton');
    
    result.passed = true;
    result.details = 'All backward compatibility aliases work correctly';
    
catch ME
    result.details = ['ERROR: ' ME.message];
end
end
