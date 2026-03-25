classdef BenchmarkPlasticity < matlab.unittest.TestCase
    % BENCHMARKPLASTICITY: Industrial plasticity benchmarks for CurveShellFEM
    methods(Test)
        function testPlasticCantilever(testCase)
            % Run the plastic cantilever benchmark as a test
            exdir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'examples');
            olddir = pwd;
            try
                cd(exdir);
                benchmark_plastic_cantilever;
            catch ME
                cd(olddir);
                rethrow(ME);
            end
            cd(olddir);
        end
        function testPlasticSnapthrough(testCase)
            exdir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'examples');
            olddir = pwd;
            try
                cd(exdir);
                benchmark_plastic_snapthrough;
            catch ME
                cd(olddir);
                rethrow(ME);
            end
            cd(olddir);
        end
        function testPlasticityUniaxial(testCase)
            exdir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'examples');
            olddir = pwd;
            try
                cd(exdir);
                test_plasticity_uniaxial;
            catch ME
                cd(olddir);
                rethrow(ME);
            end
            cd(olddir);
        end
        function testPlasticityCyclic(testCase)
            exdir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'examples');
            olddir = pwd;
            try
                cd(exdir);
                test_plasticity_cyclic;
            catch ME
                cd(olddir);
                rethrow(ME);
            end
            cd(olddir);
        end
    end
end
