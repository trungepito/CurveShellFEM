function results = test_convergence_monitor()
% TEST_CONVERGENCE_MONITOR - Unit tests for ConvergenceMonitor logic.
results = struct('passed', false, 'name', 'test_convergence_monitor', 'details', '');

try
    mon = ConvergenceMonitor();
    
    % --- Test 1: Force convergence (Default) ---
    F_ext = [100; 0; 0];
    mon.reset(F_ext);
    mon.Tolerance = 1e-6;
    
    % Iter 1: R = 10, should not converge (err = 10/100 = 0.1)
    R1 = [10; 0; 0];
    ok1 = mon.check(R1, [], [], F_ext, 1);
    assert(~ok1, 'Should not converge on iter 1');
    assert(abs(mon.ResidualHistory(1) - 0.1) < 1e-12);
    
    % Iter 2: R = 1e-5, should converge (err = 1e-5/100 = 1e-7)
    R2 = [1e-5; 0; 0];
    ok2 = mon.check(R2, [], [], F_ext, 2);
    assert(ok2, 'Should converge on iter 2');
    
    % --- Test 2: Energy convergence ---
    mon.NormType = 'energy';
    mon.reset(F_ext);
    
    % Iter 1: dU=0.1, R=10 -> E = 1.0. Ref becomes 1.0.
    dU1 = [0.1; 0; 0];
    R1  = [10; 0; 0];
    ok1 = mon.check(R1, dU1, [], F_ext, 1);
    assert(~ok1, 'Energy iter 1');
    
    % Iter 2: dU=0.01, R=1 -> E = 0.01. err = 0.01/1.0 = 0.01
    dU2 = [0.01; 0; 0];
    R2  = [1; 0; 0];
    ok2 = mon.check(R2, dU2, [], F_ext, 2);
    assert(~ok2, 'Energy iter 2');
    
    % Iter 3: dU=1e-4, R=1e-3 -> E = 1e-7. err = 1e-7/1.0 = 1e-7 < 1e-6
    dU3 = [1e-4; 0; 0];
    R3  = [1e-3; 0; 0];
    ok3 = mon.check(R3, dU3, [], F_ext, 3);
    assert(ok3, 'Energy iter 3');
    
    % --- Test 3: Displacement convergence ---
    mon.NormType = 'displacement';
    mon.reset(F_ext);
    % U_total = 1.0
    U_tot = [1; 0; 0];
    
    % Iter 1: dU=0.1 -> err = 0.1/1.0 = 0.1
    dU1 = [0.1; 0; 0];
    ok1 = mon.check([], dU1, U_tot, F_ext, 1);
    assert(~ok1);
    
    % Iter 2: dU=1e-7 -> err = 1e-7/1.0 = 1e-7
    dU2 = [1e-7; 0; 0];
    ok2 = mon.check([], dU2, U_tot, F_ext, 2);
    assert(ok2);
    
    % --- Test 4: Recommendation - Divergence ---
    mon.NormType = 'force';
    mon.reset(F_ext);
    mon.DivRatio = 10;
    mon.check([1;0;0], [], [], F_ext, 1); % R=1
    mon.check([20;0;0], [], [], F_ext, 2); % R=20 (> 10*1)
    assert(strcmp(mon.recommend(), 'abort'), 'Should recommend abort on divergence');
    
    % --- Test 5: Recommendation - Stagnation ---
    mon.reset(F_ext);
    mon.StagnationWin = 2;
    mon.check([10;0;0], [], [], F_ext, 1);
    mon.check([9.9;0;0], [], [], F_ext, 2);
    mon.check([9.8;0;0], [], [], F_ext, 3);
    assert(strcmp(mon.recommend(), 'cutback'), 'Should recommend cutback on stagnation');
    
    % --- Test 6: Recommendation - Oscillation ---
    mon.reset(F_ext);
    mon.check([10;0;0], [], [], F_ext, 1);
    mon.check([2;0;0], [], [], F_ext, 2);
    mon.check([8;0;0], [], [], F_ext, 3);
    mon.check([3;0;0], [], [], F_ext, 4);
    assert(strcmp(mon.recommend(), 'linesearch'), 'Should recommend linesearch on oscillation');
    
    results.passed = true;
    results.details = 'All ConvergenceMonitor sub-tests passed.';
    
catch ME
    results.details = sprintf('Test failed at line %d: %s', ME.stack(1).line, ME.message);
end
end
