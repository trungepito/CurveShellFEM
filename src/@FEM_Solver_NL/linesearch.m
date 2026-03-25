% E. LINE SEARCH (Backtracking)
% For the full Newton raphson, this line search is more costly!
function linesearch(obj,U_old,dU,R,F_ext_current,free_dofs)
eta = 1.0; % Start with full Newton step
controlf=0.7; % this factor is choosen for the iteration of the line search
s0=dot(R,dU); % initial value of the othorgonal condition
Flaf1=true; % control loop
R_norm_old = norm(R(free_dofs)); % Error before moving
line_iter=1; % number of iter

while Flaf1
    % 1. Create Trial Displacement
    U_trial = U_old + eta * dU;
    % 2. Fast Force Update (Do NOT re-assemble Stiffness K, just Forces F)
    % This makes line search cheap!
    F_int_trial = obj.assembleinternalforceONLY(U_trial);
    R_trial = F_ext_current - F_int_trial;
    R_norm_new = norm(R_trial(free_dofs)); % Error after moving

    % 3. The Decision
    if R_norm_new < R_norm_old
        % The error went down. We found a better spot.
        fprintf('Line Search (eta=%.2f): Residual %.2e -> %.2e\n', ...
            eta, R_norm_old, R_norm_new);
        break; % Exit loop and accept this step
    else  
        % The error went UP. We overshot. Backtrack.
        s=dot(R_trial,eta*dU);
        eta=abs(s0)/(abs(s0)+abs(s));
        % eta = eta * 0.5;
        if abs(s)<=controlf*abs(s0)
            fprintf('Line Search (eta=%.2f): s/s0 ratio %.2e \n', ...
            eta, s/s0);
            break; % Exit the loop if the condition is met
        end
        % U_trial = U_old + eta * dU;
        % F_int_trial = obj.assembleinternalforceONLY(U_trial);
        % R_trial = F_ext_current - F_int_trial;
    end
    line_iter = line_iter + 1; % Increment iteration count
    if line_iter>5
         fprintf('Line Search is not converged!\n');
         break;
    end
end

% Apply the accepted eta
obj.U = obj.U + eta * dU;