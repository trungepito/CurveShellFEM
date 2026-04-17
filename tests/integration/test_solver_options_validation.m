function results = test_solver_options_validation()
% TEST_SOLVER_OPTIONS_VALIDATION - Verify Task 15 (SolverOptions.validate())
% Checks that SolverOptions has validate() method with proper checks
results = struct('passed', false, 'name', 'test_solver_options_validation', 'details', '');

try
    % Create a solver with default options
    opts = SolverOptions();
    
    % Verify validate() method exists
    if ~ismethod(opts, 'validate')
        results.details = 'FAILED: SolverOptions missing validate() method';
        return;
    end
    
    % Call validate() on default options
    try
        opts.validate();
        validationPassed = true;
    catch
        validationPassed = false;
    end
    
    if ~validationPassed
        results.details = 'FAILED: validate() threw error on default options';
        return;
    end
    
    % Test that invalid MaxIterations fails
    opts2 = SolverOptions();
    opts2.MaxIterations = 2;  % Should fail: requires >= 3
    try
        opts2.validate();
        results.details = 'FAILED: validate() did not catch MaxIterations < 3';
        return;
    catch
        % Expected to fail
    end
    
    % Test that invalid TolForce fails
    opts3 = SolverOptions();
    opts3.TolForce = -1;  % Should fail: requires > 0
    try
        opts3.validate();
        results.details = 'FAILED: validate() did not catch TolForce <= 0';
        return;
    catch
        % Expected to fail
    end
    
    results.passed = true;
    results.details = 'SolverOptions.validate() method working correctly';
    
catch ME
    results.details = ['ERROR: ' ME.message];
end
end
