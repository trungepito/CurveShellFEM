function result = test_riks_strategy_predictor()
% TEST_RIKS_STRATEGY_PREDICTOR  Verify Riks predictor computes valid displacements

result = struct('passed', false, 'name', 'test_riks_strategy_predictor', 'details', '');

try
    % Create a simple predictor test
    strategy = RiksStrategy('Cylindrical', 1.0);
    
    % Create a simple tangent matrix (3x3 symmetric positive definite)
    KT = [2 -1 0; -1 2 -1; 0 -1 2];
    
    % Force vector
    f = [1; 0; 0];
    
    % Initial state
    u0 = zeros(3, 1);
    l0 = 0;
    dup_prev = zeros(3, 1);
    free_dofs = [1 2 3]';
    nDofs = 3;
    arc_length = 0.1;
    
    % Call predictor
    [u_pred, l_pred, dup, dlp] = strategy.predictor(KT, f, u0, l0, dup_prev, arc_length, free_dofs, nDofs);
    
    % Verify outputs
    assert(length(u_pred) == length(u0), 'Predictor output dimension mismatch');
    assert(isnumeric(l_pred), 'Load factor should be numeric');
    assert(isnumeric(dlp), 'Load factor increment should be numeric');
    
    result.passed = true;
    result.details = sprintf('Predictor: u_pred norm=%.2e, l_pred=%.4f, dlp=%.4f', ...
        norm(u_pred), l_pred, dlp);
    
catch ME
    result.details = ['ERROR: ' ME.message];
end
end
