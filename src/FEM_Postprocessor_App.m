classdef FEM_Postprocessor_App < handle
% FEM_POSTPROCESSOR_APP - Enterprise-Grade CAE Dashboard for CurveShellFEM.
%
% An interactive GUI for visualizing 3D results, mode shapes, and 
% nonlinear history. Features real-time scaling, theme switching, 
% and high-resolution export.
%
% Usage:
%   app = FEM_Postprocessor_App(PostprocessorObj)
%
% See also: FEM_Postprocessor
    % FEM_POSTPROCESSOR_APP: Professional CAE Result Dashboard
    % Integrated viewer for Linear, Buckling, and Nonlinear Analysis.
    
    properties (Access = private)
        % Core Data
        Post            % FEM_Postprocessor Reference
        Solver          % Solver Reference
        Model           % Preprocessor Reference
        
        % GUI Handles
        UIFigure
        UIAxes
        PatchDeformed
        PatchUndeformed
        ColorBar
        
        % Animation Controller
        AnimTimer
        IsPlaying = false
        
        % UI Components
        Controls        % Struct of interactive handles
        MainGrid        % uigridlayout
        SidebarGrid     % uigridlayout
        Tabs            % uitabgroup
        HeaderPanel     % uipanel
        
        % State
        AnalysisType = 'Static' % 'Static', 'Buckling', 'Nonlinear'
        CurrentStep = 1
        CurrentMode = 1
        
        % Cached Data for Speed
        NodesOrig
        Elements
        DispVec         % Current shown u [ux, uy, uz]
        FieldVals       % Current scalar results
    end
    
    methods
        function obj = FEM_Postprocessor_App(postObj)
            fprintf('[App] Initializing Enterprise Dashboard...\n');
            if nargin < 1 || isempty(postObj)
                error('FEM_Postprocessor_App:InvalidInput', 'Must provide an initialized FEM_Postprocessor object.');
            end
            
            if isa(postObj, 'FEM_Postprocessor_v2')
                obj.Post = postObj;
            elseif isa(postObj, 'FEM_Postprocessor') && ~isempty(postObj.v2delegate)
                obj.Post = postObj.v2delegate;
            else
                obj.Post = postObj;  % fallback to v1
            end
            
            obj.Solver = obj.Post.Solver;
            obj.Model = obj.Post.Model;
            
            % Integrity Check
            if isempty(obj.Model.Mesh.Nodes) || isempty(obj.Model.Mesh.Elements)
                error('FEM_Postprocessor_App:EmptyMesh', 'The provided postprocessor has no mesh data.');
            end
            
            obj.NodesOrig = obj.Model.Mesh.Nodes;
            % Reorder 8-node serendipity connectivity for CCW boundary loop
            % (Corners: 1,2,3,4 | Midsides: 5,6,7,8) -> (1,5,2,6,3,7,4,8)
            obj.Elements = obj.Model.Mesh.Elements(:, [1, 5, 2, 6, 3, 7, 4, 8]);
            
            % Initial State Detection
            obj.detectAnalysisType();
            
            % Initialize GUI
            try
                obj.initializeGUI();
            catch ME
                fprintf('[App] GUI Initialization Failed: %s\n', ME.message);
                rethrow(ME);
            end
            
            % Initial Plot
            obj.refreshData();
            fprintf('[App] Dashboard Ready.\n');
        end
        
        function delete(obj)
            if ~isempty(obj.AnimTimer) && isvalid(obj.AnimTimer)
                stop(obj.AnimTimer);
                delete(obj.AnimTimer);
            end
        end
    end
    
    methods (Access = private)
        function initializeGUI(obj)
            % 1. Main Window
            obj.UIFigure = uifigure('Name', 'CurveShellFEM | Enterprise Dashboard', ...
                'Position', [100 100 1200 800], 'Color', [0.1 0.1 0.1]);
            
            % 2. Main Layout
            obj.MainGrid = uigridlayout(obj.UIFigure, [1, 2]);
            obj.MainGrid.ColumnWidth = {'1x', 320};
            obj.MainGrid.BackgroundColor = [0.1 0.1 0.1];
            
            % 3. Viewport Panel
            panelView = uipanel(obj.MainGrid, 'BackgroundColor', [0.05 0.05 0.05], 'BorderType', 'none');
            obj.UIAxes = uiaxes(panelView, 'Units', 'normalized', 'Position', [0 0 1 1], ...
                'BackgroundColor', [0.03 0.03 0.03], 'XColor', 'none', 'YColor', 'none', 'ZColor', 'none');
            view(obj.UIAxes, 45, 30);
            axis(obj.UIAxes, 'equal'); 
            hold(obj.UIAxes, 'on');
            
            % Premium Lighting
            light(obj.UIAxes, 'Position', [1 1 5], 'Style', 'infinite', 'Color', [1 1 1]);
            light(obj.UIAxes, 'Position', [-1 -1 -5], 'Style', 'infinite', 'Color', [0.4 0.4 0.6]);
            
            % 4. Sidebar Panel
            sidebar = uipanel(obj.MainGrid, 'BackgroundColor', [0.15 0.15 0.15], 'BorderType', 'none');
            obj.SidebarGrid = uigridlayout(sidebar, [2, 1]);
            obj.SidebarGrid.RowHeight = {50, '1x'};
            
            % Header
            obj.HeaderPanel = uipanel(obj.SidebarGrid, 'BackgroundColor', [0.2 0.2 0.23], 'BorderType', 'none');
            uilabel(obj.HeaderPanel, 'Tag', 'TitleLabel', 'Text', 'ANALYSIS CONTROLLER', 'Position', [20 15 250 20], ...
                'FontWeight', 'bold', 'FontColor', [0 0.8 1], 'FontSize', 14);
            
            % Tabs
            obj.Tabs = uitabgroup(obj.SidebarGrid);
            tData    = uitab(obj.Tabs, 'Title', 'Data Selection');
            tVisuals = uitab(obj.Tabs, 'Title', 'Visuals');
            tExport  = uitab(obj.Tabs, 'Title', 'Export');
            
            obj.setupDataPanel(tData);
            obj.setupVisualsPanel(tVisuals);
            obj.setupExportPanel(tExport);
        end
        
        function detectAnalysisType(obj)
            S = obj.Solver;
            if contains(class(S), 'NL') && ~isempty(S.U_Hist)
                obj.AnalysisType = 'Nonlinear';
            elseif ~isempty(S.ModeShapes)
                obj.AnalysisType = 'Buckling';
            else
                obj.AnalysisType = 'Static';
            end
        end
        
        function setupDataPanel(obj, parent)
            dgl = uigridlayout(parent, [12, 1]);
            dgl.RowHeight = {30, 35, 30, 45, 30, 45, 30, 35, 30, 35, '1x', 45};
            dgl.BackgroundColor = [0.15 0.15 0.15];
            
            % 1. Analysis Mode
            uilabel(dgl, 'Text', 'Active Analysis:', 'FontColor', [0.8 0.8 0.8]);
            obj.Controls.AnalysisSelect = uidropdown(dgl, 'Items', {'Static', 'Buckling', 'Nonlinear'}, ...
                'Value', obj.AnalysisType, 'ValueChangedFcn', @(src,e) obj.onAnalysisChanged(src.Value));
                
            % 2. History Slider (Nonlinear)
            obj.Controls.StepLabel = uilabel(dgl, 'Text', 'Load Step / Increment:', 'FontColor', [0.8 0.8 0.8]);
            
            nSteps = 1; 
            if isprop(obj.Solver, 'U_Hist') && ~isempty(obj.Solver.U_Hist)
                nSteps = size(obj.Solver.U_Hist, 2);
            end
            
            obj.Controls.StepSlider = uislider(dgl, 'Limits', [1, max(1.1, nSteps)], 'Value', nSteps, ...
                'MajorTicks', [], 'ValueChangedFcn', @(src,e) obj.onStepChanged());
            
            % 3. Mode Selection (Buckling)
            obj.Controls.ModeLabel = uilabel(dgl, 'Text', 'Buckling Mode:', 'FontColor', [0.8 0.8 0.8]);
            
            items = {'N/A'};
            if isprop(obj.Solver, 'BucklingFactors') && ~isempty(obj.Solver.BucklingFactors)
                nModes = length(obj.Solver.BucklingFactors);
                items = arrayfun(@(i) sprintf('Mode %d', i), 1:nModes, 'UniformOutput', false);
            end
            obj.Controls.ModeSelect = uidropdown(dgl, 'Items', items, 'ValueChangedFcn', @(src,e) obj.onModeChanged());

            % 4. Field Selector
            uilabel(dgl, 'Text', 'Result Field:', 'FontColor', [0.8 0.8 0.8]);
            obj.Controls.FieldSelect = uidropdown(dgl, 'Items', {'Displacement', 'VonMises', 'Principal 1', 'Principal 2', 'SigmaX', 'SigmaY', 'TauXY', 'Pressure', 'PlasticStrain', 'PlasticFront'}, ...
                'Value', 'Displacement', 'ValueChangedFcn', @(src,e) obj.refreshData());
                
            uilabel(dgl, 'Text', 'Sampling Layer:', 'FontColor', [0.8 0.8 0.8]);
            obj.Controls.LayerSelect = uidropdown(dgl, 'Items', {'Top', 'Mid', 'Bot'}, 'Value', 'Top', ...
                'ValueChangedFcn', @(src,e) obj.refreshData());

            % 5. Theme & Main Actions
            uilabel(dgl, 'Text', 'Display Theme:', 'FontColor', [0.8 0.8 0.8]);
            obj.Controls.ThemeSelect = uidropdown(dgl, 'Items', {'Dark', 'Light'}, 'Value', 'Dark', ...
                'ValueChangedFcn', @(src,e) obj.setTheme(src.Value));

            uibutton(dgl, 'Text', 'REFRESH DATA', 'FontWeight', 'bold', 'ButtonPushedFcn', @(src,e) obj.refreshData());
            uibutton(dgl, 'Text', 'EXIT APP', 'FontColor', [1 0.2 0.2], 'ButtonPushedFcn', @(src,e) delete(obj.UIFigure));
            
            % 6. Animation Controls
            obj.Controls.AnimPanel = uipanel(dgl, 'Title', 'Animation Player', 'BackgroundColor', [0.2 0.2 0.2], 'ForegroundColor', 'w');
            obj.Controls.AnimPanel.Layout.Row = 12;
            agl = uigridlayout(obj.Controls.AnimPanel, [1, 3]);
            uibutton(agl, 'Text', 'Play', 'ButtonPushedFcn', @(src,e) obj.togglePlay());
            uibutton(agl, 'Text', 'Stop', 'ButtonPushedFcn', @(src,e) obj.stopPlay());
            obj.Controls.AnimSpeed = uidropdown(agl, 'Items', {'Fast', 'Normal', 'Slow'}, 'Value', 'Normal');
        end
        
        function setupVisualsPanel(obj, parent)
            vgl = uigridlayout(parent, [10, 1]);
            vgl.RowHeight = {30, 45, 30, 45, 30, 40, 30, 40, '1x', 40};
            vgl.BackgroundColor = [0.15 0.15 0.15];
            
            uilabel(vgl, 'Text', 'Deformation Scale:', 'FontColor', [0.8 0.8 0.8]);
            obj.Controls.ScaleSlider = uislider(vgl, 'Limits', [0 100], 'Value', 1, ...
                'ValueChangedFcn', @(src,e) obj.updateGeometry());
            
            uibutton(vgl, 'Text', 'Auto-Scale to 10%', 'ButtonPushedFcn', @(src,e) obj.autoScale());

            uilabel(vgl, 'Text', 'Colormap:', 'FontColor', 'w');
            obj.Controls.Colormap = uidropdown(vgl, 'Items', {'turbo', 'parula', 'jet', 'hot', 'cool', 'spring', 'autumn'}, ...
                'Value', 'turbo', 'ValueChangedFcn', @(src,e) colormap(obj.UIAxes, src.Value));
            
            obj.Controls.ShowUndeformed = uicheckbox(vgl, 'Text', 'Show Undeformed Grid', 'Value', 1, 'FontColor', 'w', ...
                'ValueChangedFcn', @(src,e) set(obj.PatchUndeformed, 'Visible', e.Value));
                
            obj.Controls.ViewEdges = uicheckbox(vgl, 'Text', 'Show Element Edges', 'Value', 1, 'FontColor', 'w', ...
                'ValueChangedFcn', @(src,e) set(obj.PatchDeformed, 'EdgeColor', obj.getEdgeColor(e.Value)));

            uibutton(vgl, 'Text', 'Reset Camera', 'ButtonPushedFcn', @(src,e) view(obj.UIAxes, 45, 30));
        end
        
        function setupExportPanel(obj, parent)
            egl = uigridlayout(parent, [5, 1]);
            egl.RowHeight = {50, 50, 50, '1x'};
            uibutton(egl, 'Text', 'High-Res Screenshot (.png)', 'ButtonPushedFcn', @(src,e) obj.screenshot());
            uibutton(egl, 'Text', 'Export VTK (ParaView)', 'ButtonPushedFcn', @(src,e) obj.exportVTK());
        end
        
        % --- REACTION LOGIC ---
        function onAnalysisChanged(obj, type)
            obj.AnalysisType = type;
            % Hide/Show relevant sliders
            isNL = strcmp(type, 'Nonlinear');
            isBk = strcmp(type, 'Buckling');
            obj.Controls.StepLabel.Visible = isNL;
            obj.Controls.StepSlider.Visible = isNL;
            obj.Controls.ModeLabel.Visible = isBk;
            obj.Controls.ModeSelect.Visible = isBk;
            obj.Controls.AnimPanel.Visible = isNL;
            
            obj.refreshData();
        end
        
        function onStepChanged(obj)
            obj.CurrentStep = round(obj.Controls.StepSlider.Value);
            obj.refreshData();
        end
        
        function onModeChanged(obj)
            obj.CurrentMode = obj.Controls.ModeSelect.ValueIndex;
            obj.refreshData();
        end
        
        function refreshData(obj)
            % 1. Extract Displacement Vector (Safe Access)
            try
                switch obj.AnalysisType
                    case 'Static'
                        u = obj.Solver.U;
                    case 'Nonlinear'
                        if isprop(obj.Solver, 'U_Hist') && ~isempty(obj.Solver.U_Hist)
                            u = obj.Solver.U_Hist(:, min(size(obj.Solver.U_Hist,2), obj.CurrentStep));
                        else
                            u = obj.Solver.U;
                        end
                    case 'Buckling'
                        if isprop(obj.Solver, 'ModeShapes') && ~isempty(obj.Solver.ModeShapes)
                            u = obj.Solver.ModeShapes(:, min(size(obj.Solver.ModeShapes,2), obj.CurrentMode));
                        else
                            u = obj.Solver.U;
                        end
                end
            catch
                u = obj.Solver.U;
            end
            
            % 2. Cache Displacement components
            if isempty(u), u = zeros(size(obj.NodesOrig,1)*6, 1); end
            obj.DispVec = [u(1:6:end), u(2:6:end), u(3:6:end)];
            
            % 3. Extract Field
            field = obj.Controls.FieldSelect.Value;
            if strcmp(field, 'Displacement')
                obj.FieldVals = sqrt(sum(obj.DispVec.^2, 2));
            else
                % Update Solver state for recovery logic
                obj.Solver.U = u; 
                obj.FieldVals = obj.Post.recoverNodalSmooth(field, obj.Controls.LayerSelect.Value);
            end
            
            % 4. Render
            obj.updateGeometry();
            if ~isempty(obj.PatchDeformed)
                obj.PatchDeformed.FaceVertexCData = obj.FieldVals;
            else
                obj.createInitialMeshes();
            end
        end
        
        function createInitialMeshes(obj)
            % Undeformed Ghost
            obj.PatchUndeformed = patch('Faces', obj.Elements, 'Vertices', obj.NodesOrig, ...
                'Parent', obj.UIAxes, 'FaceColor', [0.3 0.3 0.3], 'FaceAlpha', 0.1, ...
                'EdgeColor', [0.4 0.4 0.4], 'EdgeAlpha', 0.2);
            
            % Deformed
            obj.PatchDeformed = patch('Faces', obj.Elements, 'Vertices', obj.NodesOrig, ...
                'FaceVertexCData', obj.FieldVals, 'Parent', obj.UIAxes, ...
                'FaceColor', 'interp', 'EdgeColor', [0.1 0.1 0.1], 'FaceLighting', 'gouraud', ...
                'AmbientStrength', 0.6, 'DiffuseStrength', 0.8, 'SpecularStrength', 0.9);
            
            colormap(obj.UIAxes, 'turbo');
            obj.ColorBar = colorbar(obj.UIAxes, 'Color', 'w');
            title(obj.UIAxes, 'Current Field: ' + string(obj.Controls.FieldSelect.Value), 'Color', 'w');
            
            obj.updateGeometry();
        end
        
        function updateGeometry(obj)
            if isempty(obj.PatchDeformed), return; end
            scale = obj.Controls.ScaleSlider.Value;
            newVerts = obj.NodesOrig + obj.DispVec * scale;
            obj.PatchDeformed.Vertices = newVerts;
        end
        
        function autoScale(obj)
            bbox = max(obj.NodesOrig) - min(obj.NodesOrig);
            L = max(bbox);
            maxD = max(obj.FieldVals);
            if maxD == 0, return; end
            target = (0.1 * L) / maxD;
            obj.Controls.ScaleSlider.Value = min(100, max(0, target));
            obj.updateGeometry();
        end
        
        % --- ANIMATION ---
        function togglePlay(obj)
            if obj.IsPlaying
                obj.stopPlay();
            else
                obj.IsPlaying = true;
                fps = 10; if strcmp(obj.Controls.AnimSpeed.Value, 'Fast'), fps = 30; elseif strcmp(obj.Controls.AnimSpeed.Value, 'Slow'), fps = 3; end
                obj.AnimTimer = timer('Period', 1/fps, 'ExecutionMode', 'fixedRate', ...
                    'TimerFcn', @(src,e) obj.stepAnimation());
                start(obj.AnimTimer);
            end
        end
        
        function stepAnimation(obj)
            val = obj.Controls.StepSlider.Value + 1;
            if val > obj.Controls.StepSlider.Limits(2), val = 1; end
            obj.Controls.StepSlider.Value = val;
            obj.onStepChanged();
        end
        
        function stopPlay(obj)
            obj.IsPlaying = false;
            if ~isempty(obj.AnimTimer) && isvalid(obj.AnimTimer), stop(obj.AnimTimer); end
        end
        
        % --- UTILS ---
        function col = getEdgeColor(~, val)
            if val, col = [0.1 0.1 0.1]; else, col = 'none'; end
        end
        
        function screenshot(obj)
            [file, path] = uiputfile('*.png', 'Save Screenshot');
            if file
                try
                    exportgraphics(obj.UIAxes, fullfile(path, file), 'Resolution', 300);
                catch
                    % Fallback for older versions
                    saveas(obj.UIFigure, fullfile(path, file));
                end
            end
        end

        function setTheme(obj, theme)
            isLight = strcmp(theme, 'Light');
            if isLight
                bgColor = [0.94 0.94 0.94];
                panelColor = [1 1 1];
                textColor = [0.1 0.1 0.1];
                obj.UIFigure.Color = bgColor;
                obj.UIAxes.BackgroundColor = panelColor;
                obj.UIAxes.XColor = 'k'; obj.UIAxes.YColor = 'k'; obj.UIAxes.ZColor = 'k';
                obj.ColorBar.Color = 'k';
                title(obj.UIAxes, obj.UIAxes.Title.String, 'Color', 'k');
            else
                bgColor = [0.1 0.1 0.1];
                panelColor = [0.03 0.03 0.03];
                textColor = [0.8 0.8 0.8];
                obj.UIFigure.Color = bgColor;
                obj.UIAxes.BackgroundColor = panelColor;
                obj.UIAxes.XColor = 'none'; obj.UIAxes.YColor = 'none'; obj.UIAxes.ZColor = 'none';
                obj.ColorBar.Color = 'w';
                title(obj.UIAxes, obj.UIAxes.Title.String, 'Color', 'w');
            end
            
            % Update layouts if defined
            if ~isempty(obj.MainGrid)
                obj.MainGrid.BackgroundColor = bgColor;
                obj.SidebarGrid.BackgroundColor = isLight*0.1 + [0.15 0.15 0.15]; 
            end
            
            % Update all labels recursively
            allLabels = findall(obj.UIFigure, 'Type', 'uilabel');
            for i = 1:length(allLabels)
                if ~strcmp(allLabels(i).Tag, 'TitleLabel') % Keep stylized header
                    allLabels(i).FontColor = textColor;
                end
            end
        end
        
        function exportVTK(obj)
            obj.Post.exportVTK('App_Export.vtu');
            uialert(obj.UIFigure, 'Exported App_Export.vtu успешно.', 'VTK Export');
        end
    end
end
