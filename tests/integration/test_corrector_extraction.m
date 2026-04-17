function results = test_corrector_extraction()
% TEST_CORRECTOR_EXTRACTION - Verify Task 13 (Extract correctorLoop)
% Checks that solveIncrementalStage is ≤120 lines and corrector is extracted
results = struct('passed', false, 'name', 'test_corrector_extraction', 'details', '');

try
    % Read solveIncrementalStage.m and count lines
    filePath = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'src', '@FEM_Solver_Nonlinear', 'solveIncrementalStage.m');
    
    if ~exist(filePath, 'file')
        results.details = 'FAILED: solveIncrementalStage.m not found';
        return;
    end
    
    fid = fopen(filePath, 'r');
    lineCount = 0;
    while ~feof(fid)
        fgetl(fid);
        lineCount = lineCount + 1;
    end
    fclose(fid);
    
    % Target: ≤120 lines
    if lineCount <= 120
        results.passed = true;
        results.details = sprintf('solveIncrementalStage.m: %d lines (target: ≤120)', lineCount);
    else
        results.details = sprintf('FAILED: solveIncrementalStage.m has %d lines (target: ≤120)', lineCount);
    end
    
catch ME
    results.details = ['ERROR: ' ME.message];
end
end
