function verify_tangent(material, eps_target, h)
    % VERIFY_TANGENT - Numerically checks the consistency of the Algorithmic Tangent Modulus.
    %
    % Usage: verify_tangent(myMaterial, [0.01; 0.005; 0.0], 1e-7)
    
    if nargin < 3, h = 1e-7; end
    
    % Get analytical stress and tangent
    [~, Dep_analytical, ~, ~] = material.integrateStress(eps_target, zeros(3,1), 0);
    
    Dep_numerical = zeros(3,3);
    
    for i = 1:3
        eps_plus = eps_target;
        eps_plus(i) = eps_plus(i) + h;
        
        eps_minus = eps_target;
        eps_minus(i) = eps_minus(i) - h;
        
        [sig_plus, ~, ~, ~] = material.integrateStress(eps_plus, zeros(3,1), 0);
        [sig_minus, ~, ~, ~] = material.integrateStress(eps_minus, zeros(3,1), 0);
        
        Dep_numerical(:, i) = (sig_plus - sig_minus) / (2 * h);
    end
    
    error_matrix = abs(Dep_analytical - Dep_numerical);
    max_err = max(error_matrix(:));
    
    fprintf('--- Tangent Verification Report ---\n');
    fprintf('Max Difference: %.2e\n', max_err);
    if max_err < 1e-4
        fprintf('Verdict: SUCCESS (Consistent Tangent)\n');
    else
        fprintf('Verdict: FAILURE (Inconsistent Tangent)\n');
        disp('Analytical:'); disp(Dep_analytical);
        disp('Numerical:'); disp(Dep_numerical);
    end
end
