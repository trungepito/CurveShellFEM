function eta = linesearch(obj, U_old, dU, R, F_ext_current, free_dofs)
    % LINESEARCH - Backtracking utility to improve robustness.
    %
    % Returns eta (scalar in (0,1]) — the caller applies the update.
    % This method does NOT modify obj.U or any other solver state.
    eta = 1.0;
    controlf = 0.7;
    s0 = dot(R(:), dU(:));
    R_norm_old = norm(R(free_dofs));
    line_iter = 1;

    while line_iter <= 5
        U_trial = U_old + eta * dU;
        F_int_trial = obj.assembleinternalforceONLY(U_trial);
        R_trial = F_ext_current - F_int_trial;
        R_norm_new = norm(R_trial(free_dofs));

        if R_norm_new < R_norm_old
            if line_iter > 1
                fprintf(' [Standard LS accepted eta=%.3f] ', eta);
            end
            break; 
            else  
            s = dot(R_trial(:), eta * dU(:));
            eta = abs(s0) / (abs(s0) + abs(s));
            if abs(s) <= controlf * abs(s0), break; end
            fprintf(' [Standard LS backtracking... eta=%.3f] ', eta);
        end
        line_iter = line_iter + 1;
    end
    % NOTE: obj.U is NOT modified here. The caller must apply:
    %   U_curr(free_dofs) = U_old(free_dofs) + eta * dU(free_dofs);
end
