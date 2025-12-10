classdef FEM_app < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure             matlab.ui.Figure
        TabGroup             matlab.ui.container.TabGroup

        % --- PREPROCESSOR TAB ---
        PreTab               matlab.ui.container.Tab
        GeomPanel            matlab.ui.container.Panel
        SectionTypeDD        matlab.ui.control.DropDown
        DimTable             matlab.ui.control.Table
        MeshPanel            matlab.ui.container.Panel
        MeshDensityField     matlab.ui.control.NumericEditField
        MatPanel             matlab.ui.container.Panel
        E_Field              matlab.ui.control.NumericEditField
        GenGeomBtn           matlab.ui.control.Button
        PreviewAxes          matlab.ui.control.UIAxes

        % --- SOLVER TAB ---
        SolverTab            matlab.ui.container.Tab
        SolSetPanel          matlab.ui.container.Panel
        AnalysisTypeDD       matlab.ui.control.DropDown
        LoadMagField         matlab.ui.control.NumericEditField
        RunBtn               matlab.ui.control.Button
        LogArea              matlab.ui.control.TextArea

        % --- POSTPROCESSOR TAB ---
        PostTab              matlab.ui.container.Tab
        PlotSettingsPanel    matlab.ui.container.Panel
        FieldTypeDD          matlab.ui.control.DropDown
        LayerDD              matlab.ui.control.DropDown
        ScaleField           matlab.ui.control.NumericEditField
        PlotBtn              matlab.ui.control.Button
        ResultAxes           matlab.ui.control.UIAxes
    end

    % Properties for your FEA objects
    properties (Access = private)
        PreObj  % FEM_Preprocessor_v2
        SolObj  % FEM_Solver
        PostObj % FEM_Postprocessor
    end

    methods (Access = private)

        % --- CALLBACKS ---

        function updateDimTable(app, ~, ~)
            % Updates the input table based on selected section
            type = app.SectionTypeDD.Value;
            switch type
                case 'Plate'
                    d = {'L_x', 1.0; 'L_y', 1.0; 'Hole_R', 0.0};
                case 'I-Section'
                    d = {'Height', 0.3; 'Width', 0.2; 'Length', 2.0};
                case 'C-Section'
                    d = {'Height', 0.2; 'Width', 0.1; 'Radius', 0.02; 'Length', 1.0};
            end
            app.DimTable.Data = d;
        end

        function generateGeometry(app, ~, ~)
            % 1. Init Preprocessor
            E = app.E_Field.Value;
            nu = 0.3; t = 0.005; % Fixed for demo, add fields later
            app.PreObj = FEM_Preprocessor_v2(E, nu, t);

            % 2. Get Geometry Inputs
            data = app.DimTable.Data;
            type = app.SectionTypeDD.Value;

            % Map Table Data to Map/Struct
            params = containers.Map(data(:,1), [data{:,2}]);

            % 3. Call Geometry Macros
            try
                switch type
                    case 'Plate'
                        Lx = params('L_x'); Ly = params('L_y'); R = params('Hole_R');
                        if R > 0
                            app.PreObj.createPlateWithHole(Lx, R); % Assuming simplified macro exists
                        else
                            app.PreObj.createPlate([0,0,0], Lx, Ly);
                        end

                    case 'I-Section'
                        H = params('Height'); W = params('Width'); L = params('Length');
                        app.PreObj.createIBeam(H, W, L);

                    case 'C-Section'
                        H = params('Height'); W = params('Width'); L = params('Length'); R = params('Radius');
                        % Use the Extrusion logic we built
                        nodes = [W,0,0; R,0,0; 0,R,0; 0,H-R,0; R,H,0; W,H,0; R,R,0; R,H-R,0];
                        segs = [1,2,0,6; 2,3,7,4; 3,4,0,10; 4,5,8,4; 5,6,0,6];
                        app.PreObj.createExtrusion(nodes, segs, [0,0,1], L, 20);
                end

                % 4. Mesh
                density = app.MeshDensityField.Value;
                app.PreObj.meshAllPatches(density, density);

                % 5. Preview Plot
                plot(app.PreviewAxes, 0, 0); cla(app.PreviewAxes);
                patch(app.PreviewAxes, 'Vertices', app.PreObj.Mesh.Nodes, ...
                    'Faces', app.PreObj.Mesh.Elements(:,[1,2,3,4]), ...
                    'FaceColor', 'w', 'EdgeColor', 'b');
                axis(app.PreviewAxes, 'equal'); view(app.PreviewAxes, 3);
                grid(app.PreviewAxes, 'on');
                title(app.PreviewAxes, 'Mesh Preview');

                app.LogArea.Value = "Geometry Generated Successfully.";

            catch ME
                uialert(app.UIFigure, ME.message, 'Generation Error');
            end
        end

        function runSolver(app, ~, ~)
            if isempty(app.PreObj) || isempty(app.PreObj.Mesh.Nodes)
                uialert(app.UIFigure, 'Generate Geometry first!', 'Error');
                return;
            end

            app.LogArea.Value = [app.LogArea.Value; "Applying Physics..."];
            drawnow;

            % 1. Auto-Apply BCs (Demo Logic)
            % Fix Root (Z=0)
            app.PreObj.addBC('plane', [3, 0.0], 1:6);

            % 2. Auto-Apply Load
            % Find top nodes (Max Z)
            z_max = max(app.PreObj.Mesh.Nodes(:,3));
            tipNodes = app.PreObj.selectNodesOnPlane(3, z_max, 0.01);

            mag = app.LoadMagField.Value;
            % Apply Distributed Load in -Y
            app.PreObj.addNodalLoad(tipNodes, 2, -mag/length(tipNodes));

            % 3. Solve
            app.SolObj = FEM_Solver(app.PreObj);

            type = app.AnalysisTypeDD.Value;
            if strcmp(type, 'Linear Static')
                app.LogArea.Value = [app.LogArea.Value; "Solving Static System..."];
                drawnow;
                app.SolObj.solveStatic();
                app.LogArea.Value = [app.LogArea.Value; "Solution Complete."];
            else
                app.LogArea.Value = [app.LogArea.Value; "Solving Buckling..."];
                drawnow;
                app.SolObj.solveStatic(); % Need pre-stress
                app.SolObj.solveBuckling(3);
                app.LogArea.Value = [app.LogArea.Value; "Buckling Factors: " + num2str(app.SolObj.BucklingFactors')];
            end
        end

        function plotResults(app, ~, ~)
            if isempty(app.SolObj) || isempty(app.SolObj.U)
                uialert(app.UIFigure, 'Run Solver first!', 'Error');
                return;
            end

            app.PostObj = FEM_Postprocessor(app.PreObj, app.SolObj);

            type = app.FieldTypeDD.Value;
            layer = app.LayerDD.Value;
            scale = app.ScaleField.Value;

            % Manual plotting inside the axes
            % (We adapt code from FEM_Postprocessor to target specific axes)

            cla(app.ResultAxes);

            % Recover Data
            if strcmp(type, 'Displacement')
                vals = sqrt(sum(app.SolObj.U(1:6:end).^2 + app.SolObj.U(2:6:end).^2 + app.SolObj.U(3:6:end).^2, 2));
                titleStr = 'Displacement Mag';
            else
                vals = app.PostObj.recoverNodalSmooth(type, layer);
                titleStr = [type ' (' layer ')'];
            end

            % Deform Nodes
            nodes = app.PreObj.Mesh.Nodes;
            def_nodes = nodes;
            U = app.SolObj.U;
            if scale > 0
                for i=1:size(nodes,1)
                    idx = (i-1)*6;
                    def_nodes(i,:) = nodes(i,:) + U(idx+1:idx+3)' * scale;
                end
            end

            patch(app.ResultAxes, 'Vertices', def_nodes, 'Faces', app.PreObj.Mesh.Elements(:,[1,2,3,4]), ...
                'FaceVertexCData', vals, 'FaceColor', 'interp', 'EdgeColor', 'none');

            axis(app.ResultAxes, 'equal'); view(app.ResultAxes, 3);
            grid(app.ResultAxes, 'on'); colormap(app.ResultAxes, 'jet');
            colorbar(app.ResultAxes);
            title(app.ResultAxes, titleStr);
        end
    end

    % App initialization and construction
    methods (Access = private)

        function createComponents(app)
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 800 600];
            app.UIFigure.Name = 'My Custom FEA Software';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [10 10 780 580];

            % --- PRE TAB ---
            app.PreTab = uitab(app.TabGroup);
            app.PreTab.Title = 'Pre-Processing';

            % Geom Panel
            app.GeomPanel = uipanel(app.PreTab);
            app.GeomPanel.Title = 'Geometry Inputs';
            app.GeomPanel.Position = [10 350 250 200];

            uilabel(app.GeomPanel, 'Text', 'Section Type:', 'Position', [10 150 100 22]);
            app.SectionTypeDD = uidropdown(app.GeomPanel);
            app.SectionTypeDD.Items = {'Plate', 'I-Section', 'C-Section'};
            app.SectionTypeDD.Position = [100 150 140 22];
            app.SectionTypeDD.ValueChangedFcn = createCallbackFcn(app, @updateDimTable, true);

            app.DimTable = uitable(app.GeomPanel);
            app.DimTable.ColumnName = {'Param', 'Value'};
            app.DimTable.ColumnEditable = [false true];
            app.DimTable.Position = [10 10 230 130];

            % Mesh Panel
            app.MeshPanel = uipanel(app.PreTab);
            app.MeshPanel.Title = 'Meshing';
            app.MeshPanel.Position = [10 250 250 90];

            uilabel(app.MeshPanel, 'Text', 'Density (Nu/Nv):', 'Position', [10 40 100 22]);
            app.MeshDensityField = uieditfield(app.MeshPanel, 'numeric');
            app.MeshDensityField.Position = [120 40 100 22];
            app.MeshDensityField.Value = 10;

            % Material Panel
            app.MatPanel = uipanel(app.PreTab);
            app.MatPanel.Title = 'Material';
            app.MatPanel.Position = [10 180 250 60];
            uilabel(app.MatPanel, 'Text', 'Young''s Mod (Pa):', 'Position', [10 10 110 22]);
            app.E_Field = uieditfield(app.MatPanel, 'numeric');
            app.E_Field.Position = [120 10 100 22];
            app.E_Field.Value = 2e11;

            % Gen Button
            app.GenGeomBtn = uibutton(app.PreTab, 'push');
            app.GenGeomBtn.Text = 'Generate & Mesh';
            app.GenGeomBtn.Position = [10 130 250 40];
            app.GenGeomBtn.ButtonPushedFcn = createCallbackFcn(app, @generateGeometry, true);

            % Axes
            app.PreviewAxes = uiaxes(app.PreTab);
            app.PreviewAxes.Position = [280 50 480 480];

            % --- SOLVER TAB ---
            app.SolverTab = uitab(app.TabGroup);
            app.SolverTab.Title = 'Solver';

            app.SolSetPanel = uipanel(app.SolverTab);
            app.SolSetPanel.Title = 'Settings';
            app.SolSetPanel.Position = [10 400 300 150];

            uilabel(app.SolSetPanel, 'Text', 'Analysis Type:', 'Position', [10 100 100 22]);
            app.AnalysisTypeDD = uidropdown(app.SolSetPanel);
            app.AnalysisTypeDD.Items = {'Linear Static', 'Buckling'};
            app.AnalysisTypeDD.Position = [120 100 150 22];

            uilabel(app.SolSetPanel, 'Text', 'Load Mag (N):', 'Position', [10 60 100 22]);
            app.LoadMagField = uieditfield(app.SolSetPanel, 'numeric');
            app.LoadMagField.Value = 1000;
            app.LoadMagField.Position = [120 60 150 22];

            app.RunBtn = uibutton(app.SolSetPanel, 'push');
            app.RunBtn.Text = 'RUN SIMULATION';
            app.RunBtn.Position = [10 10 280 40];
            app.RunBtn.BackgroundColor = [0.4 0.8 0.4];
            app.RunBtn.ButtonPushedFcn = createCallbackFcn(app, @runSolver, true);

            app.LogArea = uitextarea(app.SolverTab);
            app.LogArea.Position = [10 10 760 380];
            app.LogArea.Editable = 'off';
            app.LogArea.Value = "Ready...";

            % --- POST TAB ---
            app.PostTab = uitab(app.TabGroup);
            app.PostTab.Title = 'Post-Processing';

            app.PlotSettingsPanel = uipanel(app.PostTab);
            app.PlotSettingsPanel.Title = 'Plot Controls';
            app.PlotSettingsPanel.Position = [10 480 760 70];

            uilabel(app.PlotSettingsPanel, 'Text', 'Field:', 'Position', [10 20 40 22]);
            app.FieldTypeDD = uidropdown(app.PlotSettingsPanel);
            app.FieldTypeDD.Items = {'Displacement', 'SigmaX', 'SigmaY', 'VonMises'};
            app.FieldTypeDD.Position = [50 20 100 22];

            uilabel(app.PlotSettingsPanel, 'Text', 'Layer:', 'Position', [170 20 40 22]);
            app.LayerDD = uidropdown(app.PlotSettingsPanel);
            app.LayerDD.Items = {'Top', 'Mid', 'Bot'};
            app.LayerDD.Position = [210 20 80 22];

            uilabel(app.PlotSettingsPanel, 'Text', 'Scale:', 'Position', [310 20 40 22]);
            app.ScaleField = uieditfield(app.PlotSettingsPanel, 'numeric');
            app.ScaleField.Value = 1.0;
            app.ScaleField.Position = [350 20 60 22];

            app.PlotBtn = uibutton(app.PlotSettingsPanel, 'push');
            app.PlotBtn.Text = 'Plot';
            app.PlotBtn.Position = [450 20 80 22];
            app.PlotBtn.ButtonPushedFcn = createCallbackFcn(app, @plotResults, true);

            app.ResultAxes = uiaxes(app.PostTab);
            app.ResultAxes.Position = [10 10 760 460];

            % Initial update
            app.updateDimTable();

            % Show the figure
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)
        function app = FEM_App
            createComponents(app)
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end