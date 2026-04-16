classdef SolutionState < handle
% SOLUTIONSTATE  Append-only archive of all solver history.
%
% The active solver is the ONLY object that calls appendStep().
% The postprocessor receives a SolutionSnapshot (see snapshot()) — never
% a live SolutionState reference.
%
% Memory management is controlled by SolverOptions.MemoryMode:
%   'all'     — keep every step in RAM (default)
%   'rolling' — keep only the last RollingWindow steps
%   'disk'    — spill older steps to MAT file (future extension)

    properties (SetAccess = private)
        % Displacement history: columns are steps
        U_Hist              double   % [nDofs × capacity]
        LambdaHist          double   % [1 × capacity]
        ArcLengthHist       double   % [1 × capacity]

        % Plastic history: cell(capacity,1), each entry cell(nElems,1) of gpData
        PlasticHistoryArchive cell

        % Reaction forces: cell(nStages,1), each [nFixed × nStepsInStage]
        ReactionHist        cell

        % Eigenanalysis results (set once, never appended)
        ModeShapes          double
        BucklingFactors     double

        % Counters
        StepCount    (1,1) double = 0
        StageCount   (1,1) double = 0
    end

    properties (Access = private)
        Capacity     (1,1) double = 0
        ChunkSize    (1,1) double = 50
        nDofs        (1,1) double
        MemoryMode   char  = 'all'
        RollingWindow (1,1) double = 100
        HasPlastic   (1,1) logical = false
    end

    methods

        function obj = SolutionState(nDofs, opts)
        % SOLUTIONSTATE  Construct with known DOF count and memory options.
        % nDofs: total number of degrees of freedom
        % opts:  SolverOptions instance (optional)
            obj.nDofs = nDofs;
            if nargin >= 2 && ~isempty(opts)
                if isprop(opts, 'MemoryMode')
                    obj.MemoryMode = opts.MemoryMode;
                end
                if isprop(opts, 'RollingWindow')
                    obj.RollingWindow = opts.RollingWindow;
                end
            end
            obj.growArrays();
        end

        function appendStep(obj, U, lambda, plasticSnap, reaction, ds)
        % APPENDSTEP  Commit one converged increment to the archive.
        %
        % U:           [nDofs×1] converged displacement
        % lambda:      scalar load factor (0 if not arc-length)
        % plasticSnap: {nElems×1} cell of gpData structs, or [] if elastic
        % reaction:    struct with .dofs and .values, or [] if none
        % ds:          arc-length radius used, or 0

            obj.StepCount = obj.StepCount + 1;

            % Grow if needed
            if obj.StepCount > obj.Capacity
                obj.growArrays();
            end

            s = obj.StepCount;
            obj.U_Hist(:, s)        = U;
            obj.LambdaHist(s)       = lambda;
            obj.ArcLengthHist(s)    = ds;

            % Plastic archive (deep copy)
            if ~isempty(plasticSnap)
                obj.HasPlastic = true;
                obj.PlasticHistoryArchive{s} = plasticSnap;
            end

            % Reaction history
            if ~isempty(reaction) && obj.StageCount > 0
                sIdx = obj.StageCount;
                if length(obj.ReactionHist) < sIdx || isempty(obj.ReactionHist{sIdx})
                    obj.ReactionHist{sIdx} = struct('dofs', reaction.dofs, ...
                        'values', reaction.values);
                else
                    obj.ReactionHist{sIdx}.values(:, end+1) = reaction.values;
                end
            end

            % Rolling mode: evict old data to free memory
            if strcmp(obj.MemoryMode, 'rolling') && s > obj.RollingWindow
                oldest = s - obj.RollingWindow;
                obj.U_Hist(:, oldest) = 0;
                obj.LambdaHist(oldest) = 0;
                obj.ArcLengthHist(oldest) = 0;
                if obj.HasPlastic
                    obj.PlasticHistoryArchive{oldest} = [];
                end
            end
        end

        function beginStage(obj)
        % BEGINSTAGE  Increment stage counter for ReactionHist indexing.
            obj.StageCount = obj.StageCount + 1;
            obj.ReactionHist{obj.StageCount} = [];
        end

        function setEigenResults(obj, modes, factors)
        % SETEIGENRESULTS  Store buckling or vibration results.
            obj.ModeShapes      = modes;
            obj.BucklingFactors = factors;
        end

        function snap = snapshot(obj)
        % SNAPSHOT  Return an immutable SolutionSnapshot for postprocessing.
        % U_Hist is COPIED (subset). PlasticArchive is shared by reference.
            s = obj.StepCount;
            snap = SolutionSnapshot();
            snap.U_Hist             = obj.U_Hist(:, 1:s);
            snap.LambdaHist         = obj.LambdaHist(1:s);
            snap.ArcLengthHist      = obj.ArcLengthHist(1:s);
            snap.PlasticHistoryArchive = obj.PlasticHistoryArchive(1:s);
            snap.ReactionHist       = obj.ReactionHist;
            snap.ModeShapes         = obj.ModeShapes;
            snap.BucklingFactors    = obj.BucklingFactors;
            snap.StepCount          = s;
        end

        function U = getU(obj, stepIdx)
        % GETU  Retrieve displacement at a specific step (read-only access).
            if stepIdx < 1 || stepIdx > obj.StepCount
                error('SolutionState:outOfRange', ...
                    'Step %d out of range [1, %d]', stepIdx, obj.StepCount);
            end
            U = obj.U_Hist(:, stepIdx);
        end

    end

    methods (Access = private)
        function growArrays(obj)
            obj.U_Hist      = [obj.U_Hist,      zeros(obj.nDofs, obj.ChunkSize)];
            obj.LambdaHist  = [obj.LambdaHist,  zeros(1, obj.ChunkSize)];
            obj.ArcLengthHist = [obj.ArcLengthHist, zeros(1, obj.ChunkSize)];
            if obj.HasPlastic || obj.Capacity == 0
                obj.PlasticHistoryArchive = [obj.PlasticHistoryArchive; ...
                    cell(obj.ChunkSize, 1)];
            end
            obj.Capacity = obj.Capacity + obj.ChunkSize;
        end
    end
end
