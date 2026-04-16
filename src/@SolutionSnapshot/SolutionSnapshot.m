classdef SolutionSnapshot
% SOLUTIONSNAPSHOT  Immutable value object given to the postprocessor.
% Never returned by a live solver — only by SolutionState.snapshot().
% The postprocessor MUST NOT call appendStep or commitHistory.
    properties
        U_Hist                double
        LambdaHist            double
        ArcLengthHist         double
        PlasticHistoryArchive cell
        ReactionHist          cell
        ModeShapes            double
        BucklingFactors       double
        StepCount             double = 0
    end
    methods
        function U = getU(obj, stepIdx)
            if stepIdx < 1 || stepIdx > obj.StepCount
                error('SolutionSnapshot:outOfRange', ...
                    'Step %d out of range [1, %d]', stepIdx, obj.StepCount);
            end
            U = obj.U_Hist(:, stepIdx);
        end
        function lambda = getLambda(obj, stepIdx)
            lambda = obj.LambdaHist(stepIdx);
        end
    end
end
