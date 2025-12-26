function success = solveStage(obj, Stage,s)

t_start = obj.Time;
t_end   = t_start + Stage.Duration;
dt      = obj.Options.InitialDt;

% Store the "Converged State" before starting the loop
U_converged = obj.U;
% Calculate the target load this stage
F_ext_target = obj.calculateGlobalTargetForce(Stage.ActiveLoads);
deltaF=F_ext_target-obj.F_ext_start; % this dF is the total load change of


% Calculate the Disp. loads or add BCs
[fixed_dofs,targets]=getDispload(obj,Stage.ActiveBCs);

startU=U_converged(fixed_dofs); % starting position of the control nodes!

deltaU=targets-U_converged(fixed_dofs); % this deltaU is the total disp change.
% Collect the reaction of this stage in a matrix
nStep=0;
S_Reaction=zeros(length(fixed_dofs),30);
while obj.Time < t_end
    % 1. Cap dt to not overshoot the end of stage
    if (obj.Time + dt) > t_end
        dt = t_end - obj.Time;
    end
    % 2. Attempt Newton-Raphson Step
    % We calculate the target value for the CURRENT trial time
    target_time = obj.Time + dt;

    % Interpolation factor (0 to 1) within this stage
    alpha = (target_time - t_start) / Stage.Duration;

    % Let's assume absolute target value:
    %Load
    F_ext=obj.F_ext_start+alpha*deltaF;

    %Disp.
    U_converged(fixed_dofs) = startU + deltaU * alpha;

    fprintf('   Step t=%.4f, dt=%.4f ... ', target_time, dt);

    [converged, U_trial,reaction, iters] = obj.newtonLoop(F_ext,U_converged,fixed_dofs);

    % 3. Evaluate Result
    if converged
        % --- SUCCESS ---
        fprintf('Converged (%d iter)\n', iters);

        % Commit State
        obj.U = U_trial;
        U_converged = U_trial; % Update backup
        obj.Time = target_time;

        % Store History
        obj.StepCount = obj.StepCount + 1;
        nStep=nStep+1;
        % 2. Store History (Dynamic resizing if we exceed pre-allocation)
        if obj.StepCount > size(obj.U_Hist, 2)
            % Double the size (standard efficient growth strategy)
            obj.U_Hist = [obj.U_Hist, zeros(size(obj.U_Hist))];
            obj.History_Time = [obj.History_Time; zeros(size(obj.History_Time))];
        end
        if nStep>size(S_Reaction,2)
            S_Reaction=[ S_Reaction,zero(size(S_Reaction))];
        end
        obj.U_Hist(:,obj.StepCount) = obj.U;
        obj.History_Time(obj.StepCount) = obj.Time;
        S_Reaction(:,nStep)=reaction;
        % 3. TRIGGER EVENT (The Listener approach)
        % Create the packet of data
        evtData = SolverEventData(obj.Time, obj.StepCount, obj.U, 1.0, 5);

        % Shout it out!
        notify(obj, 'StepConverged', evtData);

        % Adaptive: Increase dt if easy
        if iters < 5
            dt = dt * 1.5;
            dt = min(dt, obj.Options.MaxDt);
        end

        % Check if finished
        if abs(obj.Time - t_end) < 1e-9
            success = true;
            break;
        end

    else
        % --- FAILURE (Divergence) ---
        fprintf('Failed! ');

        % Check Bisection Limit
        if dt < obj.Options.MinDt
            fprintf('\n*** Step size too small (%.2e). Divergence unavoidable. ***\n', dt);
            success = false;
            break;
        end

        % Bisect (Cutback)
        dt = dt * 0.5;
        fprintf('Bisecting -> New dt=%.4f\n', dt);

        % Important: Reset U to the last known good state
        % (Implicitly done because we pass U_converged to newtonLoop next time)
    end
end
obj.F_ext_start=F_ext_target; % save for the next stage!
obj.History_Load=nStep;
obj.ReactionHist{s}=S_Reaction(:,1:nStep);
end