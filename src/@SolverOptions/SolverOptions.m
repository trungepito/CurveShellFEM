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
        
        % --- validate() ---
        function validate(obj)
        % VALIDATE  Check all critical solver options for consistency.
        %   Raises error if configuration is invalid.
        
            % MaxIterations must allow sufficient iteration
            assert(obj.MaxIterations >= 3, ...
                'SolverOptions:validate:MaxIterations', ...
                'MaxIterations must be >= 3 (got %d)', obj.MaxIterations);
            
            % Convergence tolerances must be positive and reasonable
            assert(obj.TolForce > 0 && obj.TolForce < 1, ...
                'SolverOptions:validate:TolForce', ...
                'TolForce must be in (0,1) (got %.2e)', obj.TolForce);
            
            assert(obj.TolDisp > 0 && obj.TolDisp < 1, ...
                'SolverOptions:validate:TolDisp', ...
                'TolDisp must be in (0,1) (got %.2e)', obj.TolDisp);
            
            assert(obj.TolEnergy > 0 && obj.TolEnergy < 1, ...
                'SolverOptions:validate:TolEnergy', ...
                'TolEnergy must be in (0,1) (got %.2e)', obj.TolEnergy);
            
            % Energy and displacement floors must be non-negative
            assert(obj.DispFloor >= 0, ...
                'SolverOptions:validate:DispFloor', ...
                'DispFloor must be >= 0 (got %.2e)', obj.DispFloor);
            
            assert(obj.EnergyFloor >= 0, ...
                'SolverOptions:validate:EnergyFloor', ...
                'EnergyFloor must be >= 0 (got %.2e)', obj.EnergyFloor);
            
            % Line search parameters
            assert(obj.MaxLineIter >= 1, ...
                'SolverOptions:validate:MaxLineIter', ...
                'MaxLineIter must be >= 1 (got %d)', obj.MaxLineIter);
            
            assert(obj.ArmijoC1 > 0 && obj.ArmijoC1 < 1, ...
                'SolverOptions:validate:ArmijoC1', ...
                'ArmijoC1 must be in (0,1) (got %.2e)', obj.ArmijoC1);
            
            % L-BFGS parameters
            assert(obj.LBFGSHistory >= 1, ...
                'SolverOptions:validate:LBFGSHistory', ...
                'LBFGSHistory must be >= 1 (got %d)', obj.LBFGSHistory);
            
            assert(obj.LBFGSCurvEps > 0, ...
                'SolverOptions:validate:LBFGSCurvEps', ...
                'LBFGSCurvEps must be > 0 (got %.2e)', obj.LBFGSCurvEps);
            
            % Arc-length parameters
            assert(obj.DesiredIters >= 1, ...
                'SolverOptions:validate:DesiredIters', ...
                'DesiredIters must be >= 1 (got %d)', obj.DesiredIters);
            
            assert(obj.ArcCurvatureWt >= 0 && obj.ArcCurvatureWt <= 1, ...
                'SolverOptions:validate:ArcCurvatureWt', ...
                'ArcCurvatureWt must be in [0,1] (got %.2e)', obj.ArcCurvatureWt);
            
            % Convergence monitor parameters
            assert(obj.StagnationWindow >= 1, ...
                'SolverOptions:validate:StagnationWindow', ...
                'StagnationWindow must be >= 1 (got %d)', obj.StagnationWindow);
            
            assert(obj.DivergenceRatio > 1, ...
                'SolverOptions:validate:DivergenceRatio', ...
                'DivergenceRatio must be > 1 (got %.2e)', obj.DivergenceRatio);
            
            % Condition number limit
            assert(obj.CondLimit > 1, ...
                'SolverOptions:validate:CondLimit', ...
                'CondLimit must be > 1 (got %.2e)', obj.CondLimit);
            
            % Adaptive step control
            assert(obj.MinDt > 0 && obj.MinDt <= obj.MaxDt, ...
                'SolverOptions:validate:MinDt/MaxDt', ...
                'MinDt must satisfy 0 < MinDt <= MaxDt');
            
            assert(obj.InitialDt > 0, ...
                'SolverOptions:validate:InitialDt', ...
                'InitialDt must be > 0 (got %.2e)', obj.InitialDt);
            
            % Numeric load steps
            assert(obj.numLoadSteps >= 1, ...
                'SolverOptions:validate:numLoadSteps', ...
                'numLoadSteps must be >= 1 (got %d)', obj.numLoadSteps);
            
            % NormType validation
            validNorms = {'force', 'energy', 'displacement'};
            assert(ismember(obj.NormType, validNorms), ...
                'SolverOptions:validate:NormType', ...
                'NormType must be force|energy|displacement (got %s)', obj.NormType);
            
            % MemoryMode validation
            validModes = {'all', 'rolling'};
            assert(ismember(obj.MemoryMode, validModes), ...
                'SolverOptions:validate:MemoryMode', ...
                'MemoryMode must be all|rolling (got %s)', obj.MemoryMode);
        end
    end
end