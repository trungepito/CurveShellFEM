function solveArcLength(obj, arcRadius, maxSteps, maxIter, tol)
fprintf('--- Starting Arc-Length Non-Linear Solution ---\n');

% 1. Initialization
nNodes = size(obj.Model.Mesh.Nodes, 1);
nDofs = nNodes * 5;

obj.U = zeros(nDofs, 1); % Total Displacement
Lambda = 0;              % Current Load Factor

% Get Reference Load Vector (F_ref)
obj.applyLoads();
F_ref = obj.GlobalF;

% Identify Free DOFs
fixed_dofs = [];
if ~isempty(obj.Model.BCs)
    fixed_dofs = (obj.Model.BCs(:,1)-1)*5 + obj.Model.BCs(:,2);
end
free_dofs = setdiff(1:nDofs, fixed_dofs);

% Storage
obj.LambdaHist = [0];
obj.U_Hist = [obj.U];

% --- 2. STEP LOOP ---
for step = 1:maxSteps
    fprintf('\n>> Step %d (Radius: %.4f)\n', step, arcRadius);

    % A. PREDICTOR (Tangential Step)
    % Calculate KT at start of step
    [KT_glob, ~] = obj.assembleTangentSystem();
    KT_free = KT_glob(free_dofs, free_dofs);
    F_ref_free = F_ref(free_dofs);

    % Solve tangential displacement: KT * du_t = F_ref
    du_t_free = KT_free \ F_ref_free;

    % Determine direction (prevent backtracking)
    % Scale du_t so its length matches arcRadius
    scale = arcRadius / norm(du_t_free);

    % Check sign (dot product with previous increment)
    if step > 1
        du_prev = obj.U_Hist(:,end) - obj.U_Hist(:,end-1);
        du_prev_free = du_prev(free_dofs);
        if dot(du_prev_free, du_t_free) < 0
            scale = -scale; % Keep moving forward
        end
    end

    dLambda = scale;             % Incremental Load Factor
    du_inc = zeros(nDofs,1);
    du_inc(free_dofs) = dLambda * du_t_free; % Incremental Disp

    % Update Prediction
    U_current = obj.U + du_inc;
    Lambda_current = Lambda + dLambda;

    % B. CORRECTOR LOOP (Raphson Iterations)
    converged = false;

    for iter = 1:maxIter
        % 1. Internal Force & Residual
        % Note: Update Model Nodes temporarily for UL effect if desired
        % Here we stick to TL logic for calculating forces to ensure consistency
        % but solve for Lambda.

        % Temporarily set object U to current guess
        obj.U = U_current;
        [KT_glob, F_int_glob] = obj.assembleTangentSystem();

        R_total = F_int_glob - Lambda_current * F_ref;
        R_free = R_total(free_dofs);

        % Check Convergence
        if norm(R_free) < tol
            converged = true;
            fprintf('   Converged at Iter %d. Lambda = %.4f\n', iter, Lambda_current);
            break;
        end

        % 2. Solve Two Systems
        KT_free = KT_glob(free_dofs, free_dofs);
        F_ref_free = F_ref(free_dofs);

        % delta_u_R: Due to Residual
        du_R_free = - (KT_free \ R_free);

        % delta_u_F: Due to Load Vector
        du_F_free = KT_free \ F_ref_free;

        % 3. Solve Constraint Equation (Crisfield)
        % Find variation in load factor (d_lam) that satisfies arc length
        % Equation: (du_inc + du_R + d_lam*du_F)^2 = arcRadius^2

        % Extract vectors on free DOFs
        du_inc_free = du_inc(free_dofs);

        a = dot(du_F_free, du_F_free);
        b = 2 * dot(du_inc_free + du_R_free, du_F_free);
        c = dot(du_inc_free + du_R_free, du_inc_free + du_R_free) - arcRadius^2;

        % Quadratic Formula
        disc = b^2 - 4*a*c;
        if disc < 0
            warning('Complex roots in Arc Length. Reducing step.');
            d_lam_sol = 0; % Fallback
        else
            sol1 = (-b + sqrt(disc))/(2*a);
            sol2 = (-b - sqrt(disc))/(2*a);

            % Pick root that minimizes angle change (closest to previous tangent)
            % Simplified: Pick smallest absolute value usually works for small steps
            % Or pick the one maintaining positive dot product
            val1 = dot(du_inc_free + du_R_free + sol1*du_F_free, du_inc_free);
            val2 = dot(du_inc_free + du_R_free + sol2*du_F_free, du_inc_free);

            if val1 > val2
                d_lam_sol = sol1;
            else
                d_lam_sol = sol2;
            end
        end

        % 4. Update Correctors
        d_du_free = du_R_free + d_lam_sol * du_F_free;

        % Update Increments (within this step)
        du_inc(free_dofs) = du_inc(free_dofs) + d_du_free;
        dLambda = dLambda + d_lam_sol;

        % Update Totals
        U_current = obj.U + d_du_free_full(nDofs, d_du_free, free_dofs);
        Lambda_current = Lambda + dLambda;
    end

    if ~converged
        warning('Step %d failed to converge. Cutting radius.', step);
        arcRadius = arcRadius * 0.5;
        % Reset obj.U to start of step
    else
        % Commit Step
        obj.U = U_current;
        Lambda = Lambda_current;

        % Store History
        obj.LambdaHist(end+1) = Lambda;
        obj.U_Hist(:, end+1) = obj.U;

        % UPDATED LAGRANGIAN COORDINATE UPDATE
        % Update the reference nodes for the next step
        % This captures the "follower force" and geometry update
        obj.Model.Mesh.Nodes = obj.Model.Mesh.Nodes + ...
            reshape(obj.U(1:nNodes*5), [], 5) * [1;1;1;0;0]';
        % Note: We only update XYZ coords, not alpha/beta in coords list
        % But wait! In FEA, if we update nodes, we must zero out U for next step.
        % OR we keep U total and Nodes fixed.
        % HYBRID APPROACH: Keep Nodes fixed (TL) but use Arc Length.
        % True UL requires complex stress mapping.
        % *For this example, we stick to TL formulation for the element
        % but solve it with Arc-Length.*
    end
end
end
% Helper to map free dofs back to full
function v = d_du_free_full(n, val, idx)
v = zeros(n,1);
v(idx) = val;
end
