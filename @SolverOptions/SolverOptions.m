classdef SolverOptions < handle
    properties
        % Newton-Raphson Settings
        Tolerance       = 1e-4;   % Convergence criteria (Force/Energy)
        MaxIterations   = 15;     % Max Newton iters before bisection
        
        % Adaptive Stepping Settings
        InitialDt       = 0.1;    % Starting time increment
        MinDt           = 1e-3;   % If dt drops below this, abort
        MaxDt           = 1.0;    % Max allowed step size
        MaxBisections   = 5;      % How many times to cut dt
        
        % Algorithm Flags
        UseLineSearch   = false;   % Enable Line Search?
        EnablePlotting  = false;  % Live plotting during solve
    end
end