function applyConstraints(obj)
% m= obj.Model.Constraints;
K_mod = obj.GlobalK;

% Apply BCs (Diagonal Modification Method), this one is only for the static
% solver, with fixed constraints! displacment constraints is handled by other
% method
% For every fixed DOF, set row/col to 0, diagonal to 1, Force to 0
% This implies u = 0.

if ~isempty(obj.Model.BCs)
    fixed_dofs = (obj.Model.BCs.Node-1)*6 + obj.Model.BCs.DOF;
    unique_fixed = unique(fixed_dofs);

    % Method: Penalty (Simpler for Sparse) or Identity Replacement
    % We use Identity Replacement (approximated for Sparse efficiency)

    % 1. Set diagonal to very large number (Penalty method is safer for pure sparse)
    % Or explicit replacement:
    % penalty = min(max(abs(diag(K_mod))) * 1e12, 1e23);
    penalty = 1e9;

    for i = 1:length(unique_fixed)
        dof = unique_fixed(i);
        K_mod(dof, dof) = K_mod(dof, dof)+penalty;
        % F_mod(dof) = 0; % Enforce 0 displacement
    end
end
obj.GlobalK=K_mod;
% constraint
end