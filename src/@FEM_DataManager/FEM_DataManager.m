classdef FEM_DataManager < handle
    properties
        ProjectName     % String: Base name for files
        OutputFolder    % String: Directory to save to
        Format          % 'MAT' (Binary) or 'CSV' (Text)
    end

    methods
        function obj = FEM_DataManager(name, folder, format)
            obj.ProjectName = name;
            if nargin < 2, folder = 'Results'; end
            if nargin < 3, format = 'MAT'; end

            obj.OutputFolder = folder;
            obj.Format = upper(format);

            % Create folder if it doesn't exist
            if ~exist(obj.OutputFolder, 'dir')
                mkdir(obj.OutputFolder);
            end
        end
    end
    methods
        saveState(obj, Pre, Sol, options)
        [Pre, Sol] = loadState(obj)
    end

    methods (Access = private)
        saveToMAT(obj, Pre, Sol, opt)
        exportToCSV(obj, Pre, Sol, opt)
    end


end