classdef SolverOptions < handle
% SOLVEROPTIONS  Unified configuration for all CurveShellFEM nonlinear solvers.

    properties
        % Newton-Raphson Settings
        MaxIterations    = 25;
        numLoadSteps     = 30;
        EnablePlotting   = false;

        % Adaptive Step Control
        InitialDt        = 0.1;
        MinDt            = 1e-3;
        MaxDt            = 1.0;
        MaxBisections    = 5;

        % E1 — Mixed convergence criteria
        TolForce         = 1e-4;    % ||R_free|| / ||F_ext_free||
        TolDisp          = 1e-3;    % ||dU_free|| / max(||U_free||, DispFloor)
        TolEnergy        = 1e-7;    % |dU'*R| / E_ref
        DispFloor        = 1e-12;   
        EnergyFloor      = 1e-20;   

        % E2 — Armijo backtracking line search
        UseLineSearch    = false;
        LineSearchMethod = 'standard'; % 'standard' | 'armijo'
        MaxLineIter      = 8;
        ArmijoC1         = 1e-4;

        % E3 — L-BFGS quasi-Newton
        UseQuasiNewton   = false;
        LBFGSHistory     = 6;       
        LBFGSCurvEps     = 1e-10;   
        ResetOnPlastic   = true;    

        % E4/E5/E6 — Advanced Arc-Length and Monitoring
        DesiredIters     = 4;       
        ArcCurvatureWt   = 0.4;     
        PredictorType    = 'tangent'; % 'tangent' | 'secant' | 'auto'
        CondLimit        = 1e10;      
        
        StagnationWindow = 4;       
        DivergenceRatio  = 1e3;     
        
        % Additional properties for our unified architecture
        NormType         = 'force'; % 'force' | 'energy' | 'displacement'
        MemoryMode       = 'all';   % 'all' | 'rolling' | 'disk'
        RollingWindow    = 100;     
    end

    properties (Dependent)
        % Backward compatibility aliases
        Tolerance   
        tol         
        maxIter     
        linesearch  
        UseLBFGS    % Mapping for consistency with previous plan
    end

    methods
        % --- Tolerance / tol ---
        function v = get.Tolerance(obj),  v = obj.TolForce; end
        function set.Tolerance(obj, v)
            obj.TolForce  = v;
            obj.TolEnergy = v * 1e-3;  
        end
        function v = get.tol(obj),        v = obj.TolForce; end
        function set.tol(obj, v),         obj.TolForce = v; end

        % --- maxIter ---
        function v = get.maxIter(obj),    v = obj.MaxIterations; end
        function set.maxIter(obj, v),     obj.MaxIterations = v; end

        % --- linesearch ---
        function v = get.linesearch(obj), v = obj.UseLineSearch; end
        function set.linesearch(obj, v),  obj.UseLineSearch = v; end
        
        % --- UseLBFGS (Alias for UseQuasiNewton) ---
        function v = get.UseLBFGS(obj),   v = obj.UseQuasiNewton; end
        function set.UseLBFGS(obj, v),    obj.UseQuasiNewton = v; end
    end
end