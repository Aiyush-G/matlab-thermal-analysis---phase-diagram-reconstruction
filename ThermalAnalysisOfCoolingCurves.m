classdef ThermalAnalysisOfCoolingCurves < matlab.apps.AppBase
    %THERMALANALYSISOFCOOLINGCURVES  Cooling-curve thermal analysis for phase-transformation temperatures.
    %
    %   Loads multi-channel thermocouple data, plots cooling curves, fits a
    %   smooth "no-transformation" background (polynomial and/or Newton's-law
    %   exponential), and highlights phase-transformation arrests (liquidus /
    %   solidus / eutectic) as peaks in the background-subtracted signal and
    %   its smoothed derivative. A second tab collects liquidus/solidus vs.
    %   composition pairs and plots a phase diagram.
    %
    %   This is a single-file programmatic app (same matlab.apps.AppBase
    %   architecture that App Designer generates). Run with:
    %       >> ThermalAnalysisOfCoolingCurves
    %
    %   Requires: MATLAB R2021a or newer, Curve Fitting Toolbox
    %   (fit / fittype / smooth).
    %
    %   Author:  Aiyush Gupta <aiyush.gupta@st-annes.ox.ac.uk>
    %   Version: 2.0.0 (2026)

    % ------------------------------------------------------------------
    % UI components
    % ------------------------------------------------------------------
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        GridLayout                  matlab.ui.container.GridLayout
        TabGroup                    matlab.ui.container.TabGroup

        % --- Tab 1: Analysis ---
        AnalysisTab                 matlab.ui.container.Tab
        AnalysisGrid                matlab.ui.container.GridLayout
        ControlsPanel               matlab.ui.container.Panel
        ControlsGrid                matlab.ui.container.GridLayout
        LoadFileButton              matlab.ui.control.Button
        FilepathField               matlab.ui.control.EditField
        TimeColumnDropDownLabel     matlab.ui.control.Label
        TimeColumnDropDown          matlab.ui.control.DropDown
        SampleColumnDropDownLabel   matlab.ui.control.Label
        SampleColumnDropDown        matlab.ui.control.DropDown
        RefColumnDropDownLabel      matlab.ui.control.Label
        RefColumnDropDown           matlab.ui.control.DropDown
        SampleNameFieldLabel        matlab.ui.control.Label
        SampleNameField             matlab.ui.control.EditField
        RefNameFieldLabel           matlab.ui.control.Label
        RefNameField                matlab.ui.control.EditField
        DatasetTitleFieldLabel      matlab.ui.control.Label
        DatasetTitleField           matlab.ui.control.EditField
        TimeUnitFieldLabel          matlab.ui.control.Label
        TimeUnitField               matlab.ui.control.EditField
        TempUnitFieldLabel          matlab.ui.control.Label
        TempUnitField               matlab.ui.control.EditField
        AmbientTempFieldLabel       matlab.ui.control.Label
        AmbientTempField            matlab.ui.control.NumericEditField
        SmoothWindowFieldLabel      matlab.ui.control.Label
        SmoothWindowField           matlab.ui.control.NumericEditField
        PolyOrderFieldLabel         matlab.ui.control.Label
        PolyOrderField              matlab.ui.control.NumericEditField
        BackgroundModelDropDownLabel matlab.ui.control.Label
        BackgroundModelDropDown     matlab.ui.control.DropDown
        FitStartFieldLabel          matlab.ui.control.Label
        FitStartField               matlab.ui.control.NumericEditField
        FitEndFieldLabel            matlab.ui.control.Label
        FitEndField                 matlab.ui.control.NumericEditField
        UpdateGraphsButton          matlab.ui.control.Button
        SaveSessionButton           matlab.ui.control.Button
        LoadSessionButton           matlab.ui.control.Button
        DataPreviewLabel            matlab.ui.control.Label
        PreviewTable                matlab.ui.control.Table
        OpenDatasetButton           matlab.ui.control.Button

        GraphsAndExportPanel        matlab.ui.container.Panel
        GraphsExportGrid            matlab.ui.container.GridLayout
        GraphsPanel                 matlab.ui.container.Panel
        GraphsGrid                  matlab.ui.container.GridLayout
        UIAxes1                     matlab.ui.control.UIAxes
        UIAxes2                     matlab.ui.control.UIAxes
        UIAxes3                     matlab.ui.control.UIAxes
        UIAxes4                     matlab.ui.control.UIAxes
        UIAxes5                     matlab.ui.control.UIAxes
        NotesGrid                   matlab.ui.container.GridLayout
        NotesLabel                  matlab.ui.control.Label
        NotesTextArea               matlab.ui.control.TextArea
        ExportGrid                  matlab.ui.container.GridLayout
        ExportPathFieldLabel        matlab.ui.control.Label
        ExportPathField             matlab.ui.control.EditField
        SetExportPathButton         matlab.ui.control.Button
        ExportPrefixFieldLabel      matlab.ui.control.Label
        ExportPrefixField           matlab.ui.control.EditField
        ExportButton                matlab.ui.control.Button
        ExportTypeLabel             matlab.ui.control.Label
        PNGCheckBox                 matlab.ui.control.CheckBox
        JPEGCheckBox                matlab.ui.control.CheckBox
        PDFCheckBox                 matlab.ui.control.CheckBox

        % --- Tab 2: Phase Diagram Construction ---
        PhaseDiagramTab             matlab.ui.container.Tab
        PhaseGrid                   matlab.ui.container.GridLayout
        PhaseDataPanel              matlab.ui.container.Panel
        PhaseDataGrid               matlab.ui.container.GridLayout
        ImportTableDataButton       matlab.ui.control.Button
        AddNewRowButton             matlab.ui.control.Button
        DeleteRowButton             matlab.ui.control.Button
        PhaseTable                  matlab.ui.control.Table
        CompositionLabelFieldLabel  matlab.ui.control.Label
        CompositionLabelField       matlab.ui.control.EditField
        ExportTableDataButton       matlab.ui.control.Button
        PhasePlotPanel              matlab.ui.container.Panel
        PhasePlotGrid               matlab.ui.container.GridLayout
        UIAxes6                     matlab.ui.control.UIAxes
        PhaseButtonsGrid            matlab.ui.container.GridLayout
        PlotPhaseDiagramButton      matlab.ui.control.Button
        ExportGraphButton           matlab.ui.control.Button

        % --- Tab 3: About ---
        AboutTab                    matlab.ui.container.Tab
        AboutGrid                   matlab.ui.container.GridLayout
        AboutTextArea               matlab.ui.control.TextArea
    end

    % ------------------------------------------------------------------
    % App state
    % ------------------------------------------------------------------
    properties (Access = private)
        Data double = []          % Numeric data matrix (rows x channels)
        ColumnNames cell = {}     % Column names, one per column of Data
        DataFilePath char = ''    % Full path of the loaded data file
        HasCurveFitting logical = true  % Curve Fitting Toolbox available?
    end

    properties (Constant, Access = private)
        APP_NAME    = 'Thermal Analysis of Cooling Curves'
        APP_VERSION = '2.0.0'
        SESSION_SCHEMA = 'TACC-session-v1'
    end

    % ==================================================================
    % Analysis helpers
    % ==================================================================
    methods (Access = private)

        function ok = requireData(app)
            % True if a dataset is loaded; otherwise tell the user.
            ok = ~isempty(app.Data);
            if ~ok
                uialert(app.UIFigure, ...
                    'No data loaded yet. Use "Load Data File..." first.', ...
                    'No data');
            end
        end

        function [tCol, sCol, rCol] = selectedColumns(app)
            % Current column selections (rCol = 0 means "no reference").
            tCol = app.TimeColumnDropDown.Value;
            sCol = app.SampleColumnDropDown.Value;
            rCol = app.RefColumnDropDown.Value;
        end

        function clearBothYAxes(~, ax)
            % cla only clears the ACTIVE side of a yyaxis plot; clear both.
            yyaxis(ax, 'right'); cla(ax);
            yyaxis(ax, 'left');  cla(ax);
        end

        function [w, order, i1, i2, Tenv] = validatedParameters(app, n)
            % Validate/repair analysis parameters against n data rows.
            % Throws (error) with a user-readable message when unfixable.

            % Smoothing window: odd integer >= 3
            w = round(app.SmoothWindowField.Value);
            if w < 3, w = 3; end
            if mod(w, 2) == 0, w = w + 1; end
            app.SmoothWindowField.Value = w;   % reflect repaired value

            % Polynomial order: integer 1..9 ('poly1'..'poly9')
            order = round(app.PolyOrderField.Value);
            if order < 1 || order > 9
                error('Polynomial order must be an integer between 1 and 9.');
            end
            app.PolyOrderField.Value = order;

            % Fit range
            i1 = round(app.FitStartField.Value);
            i2 = round(app.FitEndField.Value);
            if i2 <= 0 || i2 > n, i2 = n; app.FitEndField.Value = i2; end
            if i1 < 1, i1 = 1; app.FitStartField.Value = i1; end
            if i1 >= i2
                error('Background-fit start index (%d) must be smaller than end index (%d).', i1, i2);
            end
            minPts = max(order + 2, 10);
            if (i2 - i1 + 1) < minPts
                error('Background-fit range has only %d points; at least %d are needed for a degree-%d fit.', ...
                    i2 - i1 + 1, minPts, order);
            end

            Tenv = app.AmbientTempField.Value;
        end

        function s = timeLabel(app)
            u = strtrim(app.TimeUnitField.Value);
            if isempty(u), u = 's'; end
            s = sprintf('Time (%s)', u);
        end

        function s = tempLabel(app, prefix)
            u = strtrim(app.TempUnitField.Value);
            if isempty(u), u = char([176 67]); end   % default: degC
            if nargin < 2 || isempty(prefix)
                s = sprintf('Temperature (%s)', u);
            else
                s = sprintf('%s (%s)', prefix, u);
            end
        end

        function n = sampleName(app)
            n = strtrim(app.SampleNameField.Value);
            if isempty(n), n = 'Sample'; end
        end

        function n = refName(app)
            n = strtrim(app.RefNameField.Value);
            if isempty(n), n = 'Reference'; end
        end

        function updateGraphs(app)
            % Recompute and redraw all five analysis graphs.
            if ~app.requireData(), return; end

            [tCol, sCol, rCol] = app.selectedColumns();
            if tCol == sCol || (rCol ~= 0 && (rCol == tCol || rCol == sCol))
                uialert(app.UIFigure, ...
                    'Time, sample and reference channels must be different columns.', ...
                    'Column selection');
                return;
            end

            t  = app.Data(:, tCol);
            Ts = app.Data(:, sCol);
            hasRef = (rCol ~= 0);
            if hasRef, Tr = app.Data(:, rCol); end

            % Drop non-finite rows rather than crashing the plots.
            keep = isfinite(t) & isfinite(Ts);
            if hasRef, keep = keep & isfinite(Tr); end
            if ~all(keep)
                t = t(keep); Ts = Ts(keep);
                if hasRef, Tr = Tr(keep); end
            end
            n = numel(t);
            if n < 20
                uialert(app.UIFigure, ...
                    'Fewer than 20 finite data points after removing NaNs - not enough to analyse.', ...
                    'Data problem');
                return;
            end

            [w, order, i1, i2, Tenv] = app.validatedParameters(n);

            titleText = strtrim(app.DatasetTitleField.Value);
            if isempty(titleText)
                titleText = sprintf('Cooling curves: %s', app.sampleName());
            end

            % --- Graph 1: raw cooling curves --------------------------------
            ax = app.UIAxes1; cla(ax);
            if hasRef
                plot(ax, t, Tr, '-s', 'MarkerSize', 2); hold(ax, 'on');
                plot(ax, t, Ts, '-^', 'MarkerSize', 2); hold(ax, 'off');
                legend(ax, {app.refName(), app.sampleName()}, 'Location', 'best');
            else
                plot(ax, t, Ts, '-^', 'MarkerSize', 2);
                legend(ax, {app.sampleName()}, 'Location', 'best');
            end
            title(ax, titleText);
            xlabel(ax, app.timeLabel()); ylabel(ax, app.tempLabel());

            % --- Graph 2: sample temperature and (sample - reference) -------
            ax = app.UIAxes2; app.clearBothYAxes(ax);
            yyaxis(ax, 'left');
            plot(ax, t, Ts);
            ylabel(ax, app.tempLabel(app.sampleName()));
            if hasRef
                dT = Ts - Tr;
                yyaxis(ax, 'right');
                plot(ax, t, dT);
                ylabel(ax, app.tempLabel(sprintf('%s - %s', app.sampleName(), app.refName())));
                title(ax, 'Sample temperature and difference signal');
            else
                title(ax, 'Sample temperature (no reference channel selected)');
            end
            xlabel(ax, app.timeLabel());

            % --- Graph 3: difference signal and smoothed dT/dt --------------
            ax = app.UIAxes3; app.clearBothYAxes(ax);
            dt = diff(t);
            dt(dt == 0) = eps;                        % guard duplicate stamps
            deriv = diff(Ts) ./ dt;                   % true dT/dt
            tMid = (t(1:end-1) + t(2:end)) / 2;
            if app.HasCurveFitting
                derivS = smooth(deriv, w);
            else
                derivS = movmean(deriv, w);
            end
            yyaxis(ax, 'left');
            if hasRef
                plot(ax, t, Ts - Tr);
                ylabel(ax, app.tempLabel('Difference'));
            else
                plot(ax, t, Ts);
                ylabel(ax, app.tempLabel(app.sampleName()));
            end
            yyaxis(ax, 'right');
            plot(ax, tMid, derivS);
            ylabel(ax, sprintf('dT/dt (smoothed, window %d)', w));
            xlabel(ax, app.timeLabel());
            title(ax, 'Difference signal and cooling rate');

            % --- Graph 4: background fit over the selected range ------------
            ax = app.UIAxes4; cla(ax);
            xx = t(i1:i2) - t(i1);                    % time from range start
            yy = Ts(i1:i2);
            plot(ax, xx, yy, '.', 'MarkerSize', 4); hold(ax, 'on');
            legendItems = {'Data'};
            fPoly = []; fNewton = [];
            if app.HasCurveFitting
                try
                    fPoly = fit(xx, yy, sprintf('poly%d', order), 'Normalize', 'on');
                    plot(ax, xx, fPoly(xx), '-', 'LineWidth', 1.2);
                    legendItems{end+1} = sprintf('Polynomial (deg %d)', order);
                catch ME
                    app.notifyFitProblem('Polynomial background fit failed', ME);
                end
                try
                    T0 = max(yy);
                    newtonModel = fittype(@(a, x) Tenv + (T0 - Tenv) .* exp(-a * x), ...
                        'independent', 'x');
                    fNewton = fit(xx, yy, newtonModel, 'StartPoint', 1e-2, ...
                        'Lower', 0);
                    plot(ax, xx, fNewton(xx), '-', 'LineWidth', 1.2);
                    legendItems{end+1} = 'Newton cooling';
                catch ME
                    app.notifyFitProblem('Newton-cooling background fit failed', ME);
                end
            else
                uialert(app.UIFigure, ...
                    ['Curve Fitting Toolbox is not available, so the background fits ' ...
                     'in graphs 4-5 cannot be computed.'], 'Missing toolbox');
            end
            hold(ax, 'off');
            legend(ax, legendItems, 'Location', 'best');
            xlabel(ax, sprintf('%s from fit-range start', app.timeLabel()));
            ylabel(ax, app.tempLabel());
            title(ax, sprintf('Background fit (rows %d-%d)', i1, i2));

            % --- Graph 5: background-subtracted signal and derivative -------
            ax = app.UIAxes5; app.clearBothYAxes(ax);
            useNewton = startsWith(app.BackgroundModelDropDown.Value, 'Newton');
            if useNewton, fBg = fNewton; bgName = 'Newton cooling';
            else,         fBg = fPoly;   bgName = sprintf('deg-%d polynomial', order);
            end
            if isempty(fBg) && ~isempty(fNewton), fBg = fNewton; bgName = 'Newton cooling'; end
            if isempty(fBg) && ~isempty(fPoly),   fBg = fPoly;   bgName = sprintf('deg-%d polynomial', order); end
            if ~isempty(fBg)
                corrected = yy - fBg(xx);
                dxx = diff(xx); dxx(dxx == 0) = eps;
                dCorr = diff(corrected) ./ dxx;
                if app.HasCurveFitting
                    dCorrS = smooth(dCorr, w);
                else
                    dCorrS = movmean(dCorr, w);
                end
                xMid = (xx(1:end-1) + xx(2:end)) / 2;
                yyaxis(ax, 'left');
                plot(ax, xx, corrected);
                ylabel(ax, app.tempLabel('Residual'));
                yyaxis(ax, 'right');
                plot(ax, xMid, dCorrS);
                ylabel(ax, 'd(residual)/dt (smoothed)');
                xlabel(ax, sprintf('%s from fit-range start', app.timeLabel()));
                title(ax, sprintf('Background-subtracted (%s)', bgName));
            else
                title(ax, 'Background-subtracted signal');
                text(ax, 0.5, 0.5, 'Background fit unavailable', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center');
            end
        end

        function notifyFitProblem(app, what, ME)
            % Non-blocking notice that one of the fits failed.
            uialert(app.UIFigure, sprintf('%s:\n%s', what, ME.message), ...
                'Fit warning', 'Icon', 'warning');
        end

        % ----------------------------------------------------------------
        % Data ingestion
        % ----------------------------------------------------------------
        function loadDataFromFile(app, fullPath)
            % Robustly read a delimited text/CSV/Excel file into app.Data.
            % Accepts files with or without header rows; comma-, tab-,
            % space- or semicolon-delimited text; and .xlsx/.xls sheets.

            T = [];
            try
                opts = detectImportOptions(fullPath, 'VariableNamingRule', 'preserve');
                T = readtable(fullPath, opts);
            catch
                % Fall through to readmatrix below.
            end

            M = []; names = {};
            if ~isempty(T)
                isNum = varfun(@isnumeric, T, 'OutputFormat', 'uniform');
                if nnz(isNum) >= 2
                    Tn = T(:, isNum);
                    M = table2array(Tn);
                    names = Tn.Properties.VariableNames;
                end
            end
            if isempty(M)
                try
                    M = readmatrix(fullPath);
                catch ME
                    error(['Could not parse "%s" as tabular numeric data.\n\n' ...
                        'Supported formats: CSV / tab- / space- / semicolon-delimited ' ...
                        'text and Excel files, with or without one header row, ' ...
                        'containing at least two numeric columns.\n\nMATLAB said: %s'], ...
                        fullPath, ME.message);
                end
                names = arrayfun(@(k) sprintf('Column %d', k), 1:size(M, 2), ...
                    'UniformOutput', false);
            end

            % Drop columns that are entirely NaN (e.g. text columns read by
            % readmatrix, or trailing empty columns in hand-edited CSVs).
            allNaN = all(isnan(M), 1);
            M = M(:, ~allNaN);
            names = names(~allNaN);

            if size(M, 2) < 2
                error(['"%s" contains %d usable numeric column(s); at least two ' ...
                    '(time + one temperature channel) are required.'], ...
                    fullPath, size(M, 2));
            end
            if size(M, 1) < 20
                error(['"%s" contains only %d data row(s); at least 20 are needed ' ...
                    'for a meaningful cooling-curve analysis.'], fullPath, size(M, 1));
            end

            app.Data = M;
            app.ColumnNames = names;
            app.DataFilePath = fullPath;
            app.FilepathField.Value = fullPath;

            app.populateColumnDropDowns();
            app.FitStartField.Value = 1;
            app.FitEndField.Value = size(M, 1);
            app.refreshPreviewTable();
        end

        function populateColumnDropDowns(app)
            % Fill the three channel dropdowns from the loaded columns.
            nCols = numel(app.ColumnNames);
            items = cell(1, nCols);
            for k = 1:nCols
                items{k} = sprintf('%d: %s', k, app.ColumnNames{k});
            end
            app.TimeColumnDropDown.Items = items;
            app.TimeColumnDropDown.ItemsData = 1:nCols;
            app.SampleColumnDropDown.Items = items;
            app.SampleColumnDropDown.ItemsData = 1:nCols;
            app.RefColumnDropDown.Items = [{'(none)'}, items];
            app.RefColumnDropDown.ItemsData = 0:nCols;

            % Sensible defaults: time = col 1, sample = last col,
            % reference = col 2 when there are >= 3 columns.
            app.TimeColumnDropDown.Value = 1;
            app.SampleColumnDropDown.Value = nCols;
            if nCols >= 3
                app.RefColumnDropDown.Value = 2;
            else
                app.RefColumnDropDown.Value = 0;
            end
        end

        function refreshPreviewTable(app)
            % Show up to the first 500 rows in the preview table.
            nShow = min(size(app.Data, 1), 500);
            app.PreviewTable.Data = app.Data(1:nShow, :);
            app.PreviewTable.ColumnName = app.ColumnNames;
            app.PreviewTable.RowName = 'numbered';
        end

        function openFullDatasetWindow(app)
            % Full dataset in a separate resizable window.
            if ~app.requireData(), return; end
            fig = uifigure('Name', sprintf('%s - dataset', app.APP_NAME), ...
                'Position', [80 80 900 600]);
            g = uigridlayout(fig, [1 1]);
            tbl = uitable(g);
            tbl.Data = app.Data;
            tbl.ColumnName = app.ColumnNames;
            tbl.RowName = 'numbered';
        end

        % ----------------------------------------------------------------
        % Phase-diagram helpers
        % ----------------------------------------------------------------
        function M = phaseTableData(app)
            % Numeric [composition liquidus solidus] matrix from the table.
            D = app.PhaseTable.Data;
            if istable(D)
                M = table2array(D);
            else
                M = D;
            end
            if isempty(M), M = zeros(0, 3); end
        end

        function setPhaseTableData(app, M)
            app.PhaseTable.Data = M;
        end

        function refreshPhasePlot(app)
            % Draw liquidus and solidus curves from the phase table.
            M = app.phaseTableData();
            M = M(all(isfinite(M), 2), :);          % ignore incomplete rows
            ax = app.UIAxes6; cla(ax);
            if size(M, 1) < 2
                title(ax, 'Phase diagram');
                text(ax, 0.5, 0.5, 'Add at least two complete rows, then press "Plot Phase Diagram"', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center');
                return;
            end
            M = sortrows(M, 1);
            plot(ax, M(:, 1), M(:, 2), '-o', 'LineWidth', 1.2); hold(ax, 'on');
            plot(ax, M(:, 1), M(:, 3), '-s', 'LineWidth', 1.2); hold(ax, 'off');
            legend(ax, {'Liquidus', 'Solidus'}, 'Location', 'best');
            compLabel = strtrim(app.CompositionLabelField.Value);
            if isempty(compLabel), compLabel = 'Composition'; end
            xlabel(ax, compLabel);
            ylabel(ax, app.tempLabel());
            title(ax, 'Phase diagram');
            grid(ax, 'on');
        end

        % ----------------------------------------------------------------
        % Session persistence
        % ----------------------------------------------------------------
        function saveSessionToFile(app, fullPath)
            s = struct();
            s.schema        = app.SESSION_SCHEMA;
            s.appVersion    = app.APP_VERSION;
            s.savedAt       = char(datetime('now'));
            s.dataFilePath  = app.DataFilePath;
            s.data          = app.Data;
            s.columnNames   = app.ColumnNames;
            s.timeCol       = app.TimeColumnDropDown.Value;
            s.sampleCol     = app.SampleColumnDropDown.Value;
            s.refCol        = app.RefColumnDropDown.Value;
            s.sampleName    = app.SampleNameField.Value;
            s.refName       = app.RefNameField.Value;
            s.datasetTitle  = app.DatasetTitleField.Value;
            s.timeUnit      = app.TimeUnitField.Value;
            s.tempUnit      = app.TempUnitField.Value;
            s.ambientTemp   = app.AmbientTempField.Value;
            s.smoothWindow  = app.SmoothWindowField.Value;
            s.polyOrder     = app.PolyOrderField.Value;
            s.bgModel       = app.BackgroundModelDropDown.Value;
            s.fitStart      = app.FitStartField.Value;
            s.fitEnd        = app.FitEndField.Value;
            s.notes         = app.NotesTextArea.Value;
            s.phaseTable    = app.phaseTableData();
            s.compLabel     = app.CompositionLabelField.Value;
            s.exportPath    = app.ExportPathField.Value;
            s.exportPrefix  = app.ExportPrefixField.Value;
            session = s; %#ok<NASGU>
            save(fullPath, 'session');
        end

        function loadSessionFromFile(app, fullPath)
            raw = load(fullPath);
            if ~isfield(raw, 'session') || ~isfield(raw.session, 'schema') ...
                    || ~strcmp(raw.session.schema, app.SESSION_SCHEMA)
                error('"%s" is not a session file saved by this app.', fullPath);
            end
            s = raw.session;

            % Restore data first so dropdowns can be repopulated.
            app.Data = s.data;
            app.ColumnNames = s.columnNames;
            app.DataFilePath = s.dataFilePath;
            app.FilepathField.Value = s.dataFilePath;
            if ~isempty(app.Data)
                app.populateColumnDropDowns();
                app.refreshPreviewTable();
                nCols = size(app.Data, 2);
                if s.timeCol   >= 1 && s.timeCol   <= nCols, app.TimeColumnDropDown.Value   = s.timeCol;   end
                if s.sampleCol >= 1 && s.sampleCol <= nCols, app.SampleColumnDropDown.Value = s.sampleCol; end
                if s.refCol    >= 0 && s.refCol    <= nCols, app.RefColumnDropDown.Value    = s.refCol;    end
            end
            app.SampleNameField.Value        = s.sampleName;
            app.RefNameField.Value           = s.refName;
            app.DatasetTitleField.Value      = s.datasetTitle;
            app.TimeUnitField.Value          = s.timeUnit;
            app.TempUnitField.Value          = s.tempUnit;
            app.AmbientTempField.Value       = s.ambientTemp;
            app.SmoothWindowField.Value      = s.smoothWindow;
            app.PolyOrderField.Value         = s.polyOrder;
            if any(strcmp(s.bgModel, app.BackgroundModelDropDown.Items))
                app.BackgroundModelDropDown.Value = s.bgModel;
            end
            app.FitStartField.Value          = s.fitStart;
            app.FitEndField.Value            = s.fitEnd;
            app.NotesTextArea.Value          = s.notes;
            app.setPhaseTableData(s.phaseTable);
            app.CompositionLabelField.Value  = s.compLabel;
            app.ExportPathField.Value        = s.exportPath;
            app.ExportPrefixField.Value      = s.exportPrefix;

            if ~isempty(app.Data)
                app.updateGraphs();
            end
            app.refreshPhasePlot();
        end
    end

    % ==================================================================
    % Callbacks
    % ==================================================================
    methods (Access = private)

        function startupFcn(app)
            % Window identity
            app.UIFigure.Name = sprintf('%s  v%s', app.APP_NAME, app.APP_VERSION);

            % Curve Fitting Toolbox availability (fit/fittype/smooth).
            app.HasCurveFitting = (exist('fit', 'file') > 0) && ...
                                  (exist('fittype', 'file') > 0) && ...
                                  (exist('smooth', 'file') > 0);
            if ~app.HasCurveFitting
                uialert(app.UIFigure, ...
                    ['The Curve Fitting Toolbox (fit, fittype, smooth) was not found. ' ...
                     'You can still load and view data, but the background fits in ' ...
                     'graphs 4-5 will be unavailable and smoothing falls back to a ' ...
                     'moving average. Install/license the Curve Fitting Toolbox to ' ...
                     'enable full functionality.'], ...
                    'Missing dependency', 'Icon', 'warning');
            end

            % About text
            app.AboutTextArea.Value = { ...
                sprintf('%s - version %s', app.APP_NAME, app.APP_VERSION), ...
                '', ...
                'WHAT THIS APP DOES', ...
                ['Analyses cooling curves from solidifying samples to locate phase-', ...
                 'transformation temperatures (liquidus, solidus, eutectic).'], ...
                '', ...
                'METHOD', ...
                ['A sample thermocouple (and optionally a reference/furnace ', ...
                 'thermocouple) is logged during cooling. A smooth "no-transformation" ', ...
                 'background - a polynomial and/or a Newton''s-law-of-cooling ', ...
                 'exponential T(t) = T_env + (T_0 - T_env) exp(-a t) - is fitted over a ', ...
                 'user-chosen range. Subtracting the background isolates thermal ', ...
                 'arrests: latent-heat release slows cooling, producing peaks in the ', ...
                 'residual and in its smoothed time-derivative. Reading the sample ', ...
                 'temperature at these peaks gives the transformation temperatures. ', ...
                 'Repeating this for several compositions and entering the results in ', ...
                 'the Phase Diagram Construction tab builds an experimental phase ', ...
                 'diagram.'], ...
                '', ...
                'HOW TO CITE / ATTRIBUTE', ...
                ['Gupta, A. (2026). Thermal Analysis of Cooling Curves (v' app.APP_VERSION ...
                 ') [Computer software]. Department of Materials, University of Oxford. ' ...
                 'Contact: aiyush.gupta@st-annes.ox.ac.uk'], ...
                '', ...
                'REQUIREMENTS', ...
                ['Standalone version: MATLAB Runtime R2024b (free, no MATLAB license ', ...
                 'needed). Source version: MATLAB R2021a+ with Curve Fitting Toolbox.']};

            app.refreshPhasePlot();
        end

        function LoadFileButtonPushed(app, ~)
            [file, path] = uigetfile( ...
                {'*.csv;*.txt;*.dat;*.tsv;*.xlsx;*.xls', 'Data files (*.csv, *.txt, *.dat, *.tsv, *.xlsx, *.xls)'; ...
                 '*.*', 'All files'}, 'Select cooling-curve data file');
            if isequal(file, 0), return; end
            try
                app.loadDataFromFile(fullfile(path, file));
            catch ME
                uialert(app.UIFigure, ME.message, 'File load error');
            end
        end

        function UpdateGraphsButtonPushed(app, ~)
            try
                app.updateGraphs();
            catch ME
                uialert(app.UIFigure, ME.message, 'Analysis error');
            end
        end

        function OpenDatasetButtonPushed(app, ~)
            try
                app.openFullDatasetWindow();
            catch ME
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end

        function SetExportPathButtonPushed(app, ~)
            folder = uigetdir();
            if ~isequal(folder, 0)
                app.ExportPathField.Value = folder;
            end
        end

        function ExportButtonPushed(app, ~)
            try
                folder = app.ExportPathField.Value;
                if isempty(folder)
                    uialert(app.UIFigure, 'Choose an export folder first ("Set Export Path...").', 'Export');
                    return;
                end
                if ~isfolder(folder)
                    uialert(app.UIFigure, sprintf('Export folder does not exist:\n%s', folder), 'Export');
                    return;
                end
                prefix = strtrim(app.ExportPrefixField.Value);
                if isempty(prefix)
                    [~, base, ~] = fileparts(app.DataFilePath);
                    if isempty(base), base = 'thermal_analysis'; end
                    prefix = base;
                end
                formats = {};
                if app.PNGCheckBox.Value,  formats{end+1} = 'png';  end
                if app.JPEGCheckBox.Value, formats{end+1} = 'jpg';  end
                if app.PDFCheckBox.Value,  formats{end+1} = 'pdf';  end
                if isempty(formats)
                    uialert(app.UIFigure, 'Tick at least one export format (PNG / JPEG / PDF).', 'Export');
                    return;
                end
                axesList = {app.UIAxes1, app.UIAxes2, app.UIAxes3, app.UIAxes4, app.UIAxes5};
                tags = {'1_cooling_curves', '2_difference', '3_derivative', ...
                        '4_background_fit', '5_background_subtracted'};
                for i = 1:numel(axesList)
                    for j = 1:numel(formats)
                        fname = fullfile(folder, sprintf('%s_%s.%s', prefix, tags{i}, formats{j}));
                        exportgraphics(axesList{i}, fname);
                    end
                end
                % Save notes alongside the graphs (prefixed, so runs don't clobber).
                notes = app.NotesTextArea.Value;
                if ~isempty(notes) && ~(numel(notes) == 1 && isempty(strtrim(notes{1})))
                    fid = fopen(fullfile(folder, sprintf('%s_Notes.txt', prefix)), 'w');
                    if fid ~= -1
                        fprintf(fid, '%s\n', notes{:});
                        fclose(fid);
                    else
                        uialert(app.UIFigure, 'Graphs exported, but the notes file could not be written.', ...
                            'Export', 'Icon', 'warning');
                        return;
                    end
                end
                uialert(app.UIFigure, sprintf('Exported %d graph(s) to:\n%s', ...
                    numel(axesList) * numel(formats), folder), 'Export complete', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ME.message, 'Export error');
            end
        end

        function SaveSessionButtonPushed(app, ~)
            try
                [file, path] = uiputfile('*.mat', 'Save session as', 'thermal_analysis_session.mat');
                if isequal(file, 0), return; end
                app.saveSessionToFile(fullfile(path, file));
                uialert(app.UIFigure, 'Session saved.', 'Session', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ME.message, 'Session save error');
            end
        end

        function LoadSessionButtonPushed(app, ~)
            try
                [file, path] = uigetfile('*.mat', 'Load session');
                if isequal(file, 0), return; end
                app.loadSessionFromFile(fullfile(path, file));
            catch ME
                uialert(app.UIFigure, ME.message, 'Session load error');
            end
        end

        % --- Phase Diagram Construction tab -----------------------------
        function ImportTableDataButtonPushed(app, ~)
            try
                [file, path] = uigetfile( ...
                    {'*.csv;*.xlsx;*.xls;*.txt', 'Table files (*.csv, *.xlsx, *.xls, *.txt)'}, ...
                    'Import composition / liquidus / solidus table');
                if isequal(file, 0), return; end
                T = readtable(fullfile(path, file), ...
                    detectImportOptions(fullfile(path, file), 'VariableNamingRule', 'preserve'));
                isNum = varfun(@isnumeric, T, 'OutputFormat', 'uniform');
                Tn = T(:, isNum);
                if width(Tn) < 3
                    error(['The file must contain at least three numeric columns ' ...
                        '(composition, liquidus, solidus); found %d.'], width(Tn));
                end
                % Map columns by header keywords where possible, else by order.
                names = lower(Tn.Properties.VariableNames);
                iComp = find(contains(names, {'comp', 'wt', 'at%', 'x_'}), 1);
                iLiq  = find(contains(names, 'liq'), 1);
                iSol  = find(contains(names, 'sol'), 1);
                if isempty(iComp) || isempty(iLiq) || isempty(iSol) ...
                        || numel(unique([iComp iLiq iSol])) < 3
                    iComp = 1; iLiq = 2; iSol = 3;
                end
                Mnew = table2array(Tn(:, [iComp iLiq iSol]));

                Mold = app.phaseTableData();
                if ~isempty(Mold)
                    choice = uiconfirm(app.UIFigure, ...
                        'The table already has data. Replace it or append the imported rows?', ...
                        'Import table data', ...
                        'Options', {'Replace', 'Append', 'Cancel'}, ...
                        'DefaultOption', 1, 'CancelOption', 3);
                    switch choice
                        case 'Append',  Mnew = [Mold; Mnew];
                        case 'Cancel',  return;
                    end
                end
                app.setPhaseTableData(Mnew);
                app.refreshPhasePlot();
            catch ME
                uialert(app.UIFigure, ME.message, 'Import error');
            end
        end

        function AddNewRowButtonPushed(app, ~)
            try
                M = app.phaseTableData();
                app.setPhaseTableData([M; NaN NaN NaN]);
            catch ME
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end

        function DeleteRowButtonPushed(app, ~)
            try
                sel = app.PhaseTable.Selection;   % row indices (SelectionType = 'row')
                if isempty(sel)
                    uialert(app.UIFigure, 'Select one or more rows to delete first.', 'Delete row');
                    return;
                end
                rows = unique(sel(:));
                M = app.phaseTableData();
                M(rows(rows <= size(M, 1)), :) = [];
                app.setPhaseTableData(M);
                app.refreshPhasePlot();
            catch ME
                uialert(app.UIFigure, ME.message, 'Error');
            end
        end

        function ExportTableDataButtonPushed(app, ~)
            try
                M = app.phaseTableData();
                if isempty(M)
                    uialert(app.UIFigure, 'The table is empty - nothing to export.', 'Export table');
                    return;
                end
                [file, path] = uiputfile( ...
                    {'*.csv', 'CSV file (*.csv)'; '*.xlsx', 'Excel workbook (*.xlsx)'}, ...
                    'Export table data as', 'phase_diagram_points.csv');
                if isequal(file, 0), return; end
                T = array2table(M, 'VariableNames', {'Composition', 'Liquidus', 'Solidus'});
                writetable(T, fullfile(path, file));
                uialert(app.UIFigure, 'Table exported.', 'Export table', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ME.message, 'Export error');
            end
        end

        function PlotPhaseDiagramButtonPushed(app, ~)
            try
                app.refreshPhasePlot();
            catch ME
                uialert(app.UIFigure, ME.message, 'Plot error');
            end
        end

        function ExportGraphButtonPushed(app, ~)
            try
                M = app.phaseTableData();
                if size(M(all(isfinite(M), 2), :), 1) < 2
                    uialert(app.UIFigure, ...
                        'Plot the phase diagram first (at least two complete rows needed).', ...
                        'Export graph');
                    return;
                end
                app.refreshPhasePlot();   % make sure the plot is current
                [file, path] = uiputfile( ...
                    {'*.png', 'PNG image (*.png)'; '*.jpg', 'JPEG image (*.jpg)'; ...
                     '*.pdf', 'PDF (*.pdf)'}, 'Export phase diagram as', 'phase_diagram.png');
                if isequal(file, 0), return; end
                exportgraphics(app.UIAxes6, fullfile(path, file));
                uialert(app.UIFigure, 'Phase diagram exported.', 'Export graph', 'Icon', 'success');
            catch ME
                uialert(app.UIFigure, ME.message, 'Export error');
            end
        end
    end

    % ==================================================================
    % Component creation
    % ==================================================================
    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [80 80 1200 700];
            app.UIFigure.Name = app.APP_NAME;

            app.GridLayout = uigridlayout(app.UIFigure, [1 1]);
            app.GridLayout.Padding = [0 0 0 0];

            app.TabGroup = uitabgroup(app.GridLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            % ============================================================
            % Tab 1: Analysis
            % ============================================================
            app.AnalysisTab = uitab(app.TabGroup);
            app.AnalysisTab.Title = 'Analysis';

            app.AnalysisGrid = uigridlayout(app.AnalysisTab, [1 2]);
            app.AnalysisGrid.ColumnWidth = {320, '1x'};
            app.AnalysisGrid.RowHeight = {'1x'};

            % ---- Controls panel (left) --------------------------------
            app.ControlsPanel = uipanel(app.AnalysisGrid);
            app.ControlsPanel.Title = 'Controls';
            app.ControlsPanel.Layout.Row = 1;
            app.ControlsPanel.Layout.Column = 1;

            app.ControlsGrid = uigridlayout(app.ControlsPanel);
            app.ControlsGrid.ColumnWidth = {'fit', '1x'};
            % Rows 1-16: file + channel + metadata + parameter controls.
            % Row 17: Update Graphs. Row 18: session buttons.
            % Row 19: preview label + full-dataset button. Row 20: preview table.
            app.ControlsGrid.RowHeight = [repmat({'fit'}, 1, 19), {'1x'}];
            app.ControlsGrid.Scrollable = 'on';
            app.ControlsGrid.RowSpacing = 4;

            r = 1;
            app.LoadFileButton = uibutton(app.ControlsGrid, 'push');
            app.LoadFileButton.ButtonPushedFcn = createCallbackFcn(app, @LoadFileButtonPushed, true);
            app.LoadFileButton.Layout.Row = r; app.LoadFileButton.Layout.Column = [1 2];
            app.LoadFileButton.Text = 'Load Data File...';
            app.LoadFileButton.Tooltip = ['Open a CSV / text / Excel file of logged temperatures. ' ...
                'One column must be time; every other numeric column is available as a channel. ' ...
                'A single header row is detected automatically.'];

            r = r + 1;
            app.FilepathField = uieditfield(app.ControlsGrid, 'text');
            app.FilepathField.Editable = 'off';
            app.FilepathField.Layout.Row = r; app.FilepathField.Layout.Column = [1 2];
            app.FilepathField.Placeholder = 'No file loaded';
            app.FilepathField.Tooltip = 'Path of the currently loaded data file.';

            r = r + 1;
            app.TimeColumnDropDownLabel = uilabel(app.ControlsGrid);
            app.TimeColumnDropDownLabel.Text = 'Time column';
            app.TimeColumnDropDownLabel.Layout.Row = r; app.TimeColumnDropDownLabel.Layout.Column = 1;
            app.TimeColumnDropDown = uidropdown(app.ControlsGrid);
            app.TimeColumnDropDown.Items = {'(load a file)'}; app.TimeColumnDropDown.ItemsData = 1;
            app.TimeColumnDropDown.Layout.Row = r; app.TimeColumnDropDown.Layout.Column = 2;
            app.TimeColumnDropDown.Tooltip = 'Which column holds the time stamps.';

            r = r + 1;
            app.SampleColumnDropDownLabel = uilabel(app.ControlsGrid);
            app.SampleColumnDropDownLabel.Text = 'Sample channel';
            app.SampleColumnDropDownLabel.Layout.Row = r; app.SampleColumnDropDownLabel.Layout.Column = 1;
            app.SampleColumnDropDown = uidropdown(app.ControlsGrid);
            app.SampleColumnDropDown.Items = {'(load a file)'}; app.SampleColumnDropDown.ItemsData = 1;
            app.SampleColumnDropDown.Layout.Row = r; app.SampleColumnDropDown.Layout.Column = 2;
            app.SampleColumnDropDown.Tooltip = ['Thermocouple embedded in the solidifying sample - ' ...
                'the channel that is analysed for thermal arrests.'];

            r = r + 1;
            app.RefColumnDropDownLabel = uilabel(app.ControlsGrid);
            app.RefColumnDropDownLabel.Text = 'Reference channel';
            app.RefColumnDropDownLabel.Layout.Row = r; app.RefColumnDropDownLabel.Layout.Column = 1;
            app.RefColumnDropDown = uidropdown(app.ControlsGrid);
            app.RefColumnDropDown.Items = {'(none)'}; app.RefColumnDropDown.ItemsData = 0;
            app.RefColumnDropDown.Layout.Row = r; app.RefColumnDropDown.Layout.Column = 2;
            app.RefColumnDropDown.Tooltip = ['Optional furnace / reference thermocouple. The ' ...
                'sample-minus-reference difference makes arrests easier to see. Choose "(none)" ' ...
                'if you only logged one channel.'];

            r = r + 1;
            app.SampleNameFieldLabel = uilabel(app.ControlsGrid);
            app.SampleNameFieldLabel.Text = 'Sample name';
            app.SampleNameFieldLabel.Layout.Row = r; app.SampleNameFieldLabel.Layout.Column = 1;
            app.SampleNameField = uieditfield(app.ControlsGrid, 'text');
            app.SampleNameField.Value = 'Sample';
            app.SampleNameField.Layout.Row = r; app.SampleNameField.Layout.Column = 2;
            app.SampleNameField.Tooltip = 'Used in graph titles and legends, e.g. "Al-12Si ingot".';

            r = r + 1;
            app.RefNameFieldLabel = uilabel(app.ControlsGrid);
            app.RefNameFieldLabel.Text = 'Reference name';
            app.RefNameFieldLabel.Layout.Row = r; app.RefNameFieldLabel.Layout.Column = 1;
            app.RefNameField = uieditfield(app.ControlsGrid, 'text');
            app.RefNameField.Value = 'Furnace';
            app.RefNameField.Layout.Row = r; app.RefNameField.Layout.Column = 2;
            app.RefNameField.Tooltip = 'Legend label for the reference channel, e.g. "Furnace wall".';

            r = r + 1;
            app.DatasetTitleFieldLabel = uilabel(app.ControlsGrid);
            app.DatasetTitleFieldLabel.Text = 'Plot title';
            app.DatasetTitleFieldLabel.Layout.Row = r; app.DatasetTitleFieldLabel.Layout.Column = 1;
            app.DatasetTitleField = uieditfield(app.ControlsGrid, 'text');
            app.DatasetTitleField.Layout.Row = r; app.DatasetTitleField.Layout.Column = 2;
            app.DatasetTitleField.Placeholder = '(auto from sample name)';
            app.DatasetTitleField.Tooltip = 'Optional title for graph 1. Leave blank to auto-generate.';

            r = r + 1;
            app.TimeUnitFieldLabel = uilabel(app.ControlsGrid);
            app.TimeUnitFieldLabel.Text = 'Time unit';
            app.TimeUnitFieldLabel.Layout.Row = r; app.TimeUnitFieldLabel.Layout.Column = 1;
            app.TimeUnitField = uieditfield(app.ControlsGrid, 'text');
            app.TimeUnitField.Value = 's';
            app.TimeUnitField.Layout.Row = r; app.TimeUnitField.Layout.Column = 2;
            app.TimeUnitField.Tooltip = 'Axis-label unit for time (s, min, h, ...). Purely cosmetic.';

            r = r + 1;
            app.TempUnitFieldLabel = uilabel(app.ControlsGrid);
            app.TempUnitFieldLabel.Text = 'Temperature unit';
            app.TempUnitFieldLabel.Layout.Row = r; app.TempUnitFieldLabel.Layout.Column = 1;
            app.TempUnitField = uieditfield(app.ControlsGrid, 'text');
            app.TempUnitField.Value = char([176 67]);   % degC
            app.TempUnitField.Layout.Row = r; app.TempUnitField.Layout.Column = 2;
            app.TempUnitField.Tooltip = ['Axis-label unit for temperature. Make sure the ambient ' ...
                'temperature below is entered in the same unit.'];

            r = r + 1;
            app.AmbientTempFieldLabel = uilabel(app.ControlsGrid);
            app.AmbientTempFieldLabel.Text = 'Ambient temp';
            app.AmbientTempFieldLabel.Layout.Row = r; app.AmbientTempFieldLabel.Layout.Column = 1;
            app.AmbientTempField = uieditfield(app.ControlsGrid, 'numeric');
            app.AmbientTempField.Value = 20;
            app.AmbientTempField.Layout.Row = r; app.AmbientTempField.Layout.Column = 2;
            app.AmbientTempField.Tooltip = ['T_env in the Newton''s-law background fit ' ...
                'T(t) = T_env + (T_0 - T_env) exp(-a t). Use the temperature the sample would ' ...
                'eventually cool to, in the unit above.'];

            r = r + 1;
            app.SmoothWindowFieldLabel = uilabel(app.ControlsGrid);
            app.SmoothWindowFieldLabel.Text = 'Smoothing window';
            app.SmoothWindowFieldLabel.Layout.Row = r; app.SmoothWindowFieldLabel.Layout.Column = 1;
            app.SmoothWindowField = uieditfield(app.ControlsGrid, 'numeric');
            app.SmoothWindowField.Value = 11;
            app.SmoothWindowField.Limits = [3 9999];
            app.SmoothWindowField.RoundFractionalValues = 'on';
            app.SmoothWindowField.Layout.Row = r; app.SmoothWindowField.Layout.Column = 2;
            app.SmoothWindowField.Tooltip = ['Moving-average window (in points, odd) applied to ' ...
                'derivatives in graphs 3 and 5. Larger = smoother but broader peaks.'];

            r = r + 1;
            app.PolyOrderFieldLabel = uilabel(app.ControlsGrid);
            app.PolyOrderFieldLabel.Text = 'Polynomial order';
            app.PolyOrderFieldLabel.Layout.Row = r; app.PolyOrderFieldLabel.Layout.Column = 1;
            app.PolyOrderField = uieditfield(app.ControlsGrid, 'numeric');
            app.PolyOrderField.Value = 9;
            app.PolyOrderField.Limits = [1 9];
            app.PolyOrderField.RoundFractionalValues = 'on';
            app.PolyOrderField.Layout.Row = r; app.PolyOrderField.Layout.Column = 2;
            app.PolyOrderField.Tooltip = 'Degree of the polynomial background fit in graph 4 (1-9).';

            r = r + 1;
            app.BackgroundModelDropDownLabel = uilabel(app.ControlsGrid);
            app.BackgroundModelDropDownLabel.Text = 'Subtract background';
            app.BackgroundModelDropDownLabel.Layout.Row = r; app.BackgroundModelDropDownLabel.Layout.Column = 1;
            app.BackgroundModelDropDown = uidropdown(app.ControlsGrid);
            app.BackgroundModelDropDown.Items = {'Newton cooling (exponential)', 'Polynomial'};
            app.BackgroundModelDropDown.Value = 'Newton cooling (exponential)';
            app.BackgroundModelDropDown.Layout.Row = r; app.BackgroundModelDropDown.Layout.Column = 2;
            app.BackgroundModelDropDown.Tooltip = ['Which fitted background graph 5 subtracts from ' ...
                'the data. Newton cooling is physically motivated; the polynomial can follow ' ...
                'more complicated furnace behaviour.'];

            r = r + 1;
            app.FitStartFieldLabel = uilabel(app.ControlsGrid);
            app.FitStartFieldLabel.Text = 'Fit range start (row)';
            app.FitStartFieldLabel.Layout.Row = r; app.FitStartFieldLabel.Layout.Column = 1;
            app.FitStartField = uieditfield(app.ControlsGrid, 'numeric');
            app.FitStartField.Value = 1;
            app.FitStartField.Layout.Row = r; app.FitStartField.Layout.Column = 2;
            app.FitStartField.Tooltip = ['First data row of the background-fit range (see the row ' ...
                'numbers in the data preview). Choose a range that brackets the transformation.'];

            r = r + 1;
            app.FitEndFieldLabel = uilabel(app.ControlsGrid);
            app.FitEndFieldLabel.Text = 'Fit range end (row)';
            app.FitEndFieldLabel.Layout.Row = r; app.FitEndFieldLabel.Layout.Column = 1;
            app.FitEndField = uieditfield(app.ControlsGrid, 'numeric');
            app.FitEndField.Value = 1;
            app.FitEndField.Layout.Row = r; app.FitEndField.Layout.Column = 2;
            app.FitEndField.Tooltip = 'Last data row of the background-fit range (set to the last row after loading).';

            r = r + 1;   % row 17: Update Graphs
            app.UpdateGraphsButton = uibutton(app.ControlsGrid, 'push');
            app.UpdateGraphsButton.ButtonPushedFcn = createCallbackFcn(app, @UpdateGraphsButtonPushed, true);
            app.UpdateGraphsButton.Layout.Row = r; app.UpdateGraphsButton.Layout.Column = [1 2];
            app.UpdateGraphsButton.Text = 'Update Graphs';
            app.UpdateGraphsButton.FontWeight = 'bold';
            app.UpdateGraphsButton.Tooltip = 'Recompute all five graphs with the current settings.';

            r = r + 1;   % row 18: session save/load
            app.SaveSessionButton = uibutton(app.ControlsGrid, 'push');
            app.SaveSessionButton.ButtonPushedFcn = createCallbackFcn(app, @SaveSessionButtonPushed, true);
            app.SaveSessionButton.Layout.Row = r; app.SaveSessionButton.Layout.Column = 1;
            app.SaveSessionButton.Text = 'Save Session...';
            app.SaveSessionButton.Tooltip = 'Save data, settings, notes and the phase table to a .mat session file.';

            app.LoadSessionButton = uibutton(app.ControlsGrid, 'push');
            app.LoadSessionButton.ButtonPushedFcn = createCallbackFcn(app, @LoadSessionButtonPushed, true);
            app.LoadSessionButton.Layout.Row = r; app.LoadSessionButton.Layout.Column = 2;
            app.LoadSessionButton.Text = 'Load Session...';
            app.LoadSessionButton.Tooltip = 'Restore a previously saved session file.';

            r = r + 1;   % row 19: preview label + full-dataset button
            app.DataPreviewLabel = uilabel(app.ControlsGrid);
            app.DataPreviewLabel.Text = 'Data preview';
            app.DataPreviewLabel.Layout.Row = r; app.DataPreviewLabel.Layout.Column = 1;
            app.OpenDatasetButton = uibutton(app.ControlsGrid, 'push');
            app.OpenDatasetButton.ButtonPushedFcn = createCallbackFcn(app, @OpenDatasetButtonPushed, true);
            app.OpenDatasetButton.Layout.Row = r; app.OpenDatasetButton.Layout.Column = 2;
            app.OpenDatasetButton.Text = 'Open Full Dataset';
            app.OpenDatasetButton.Tooltip = 'Show every row of the dataset in a separate window.';

            r = r + 1;   % row 20: preview table (stretches)
            app.PreviewTable = uitable(app.ControlsGrid);
            app.PreviewTable.Layout.Row = r; app.PreviewTable.Layout.Column = [1 2];
            app.PreviewTable.ColumnName = {};
            app.PreviewTable.Tooltip = 'First 500 rows of the loaded file. Row numbers here are the indices used by the fit range.';

            % ---- Graphs + export panel (right) ------------------------
            app.GraphsAndExportPanel = uipanel(app.AnalysisGrid);
            app.GraphsAndExportPanel.Title = 'Graphs and Export';
            app.GraphsAndExportPanel.Layout.Row = 1;
            app.GraphsAndExportPanel.Layout.Column = 2;

            app.GraphsExportGrid = uigridlayout(app.GraphsAndExportPanel, [2 1]);
            app.GraphsExportGrid.RowHeight = {'1x', 'fit'};
            app.GraphsExportGrid.Padding = [0 0 0 0];

            app.GraphsPanel = uipanel(app.GraphsExportGrid);
            app.GraphsPanel.Title = 'Graphs';
            app.GraphsPanel.Layout.Row = 1;
            app.GraphsPanel.Layout.Column = 1;

            app.GraphsGrid = uigridlayout(app.GraphsPanel, [2 3]);

            app.UIAxes1 = uiaxes(app.GraphsGrid);
            title(app.UIAxes1, 'Cooling curves');
            app.UIAxes1.Layout.Row = 1; app.UIAxes1.Layout.Column = 1;

            app.UIAxes2 = uiaxes(app.GraphsGrid);
            title(app.UIAxes2, 'Sample and difference');
            app.UIAxes2.Layout.Row = 1; app.UIAxes2.Layout.Column = 2;

            app.UIAxes3 = uiaxes(app.GraphsGrid);
            title(app.UIAxes3, 'Difference and cooling rate');
            app.UIAxes3.Layout.Row = 1; app.UIAxes3.Layout.Column = 3;

            app.UIAxes4 = uiaxes(app.GraphsGrid);
            title(app.UIAxes4, 'Background fit');
            app.UIAxes4.Layout.Row = 2; app.UIAxes4.Layout.Column = 1;

            app.UIAxes5 = uiaxes(app.GraphsGrid);
            title(app.UIAxes5, 'Background-subtracted');
            app.UIAxes5.Layout.Row = 2; app.UIAxes5.Layout.Column = 2;

            app.NotesGrid = uigridlayout(app.GraphsGrid, [2 1]);
            app.NotesGrid.RowHeight = {'fit', '1x'};
            app.NotesGrid.Padding = [0 0 0 0];
            app.NotesGrid.Layout.Row = 2; app.NotesGrid.Layout.Column = 3;

            app.NotesLabel = uilabel(app.NotesGrid);
            app.NotesLabel.Text = 'Notes';
            app.NotesLabel.Layout.Row = 1; app.NotesLabel.Layout.Column = 1;

            app.NotesTextArea = uitextarea(app.NotesGrid);
            app.NotesTextArea.Layout.Row = 2; app.NotesTextArea.Layout.Column = 1;
            app.NotesTextArea.Placeholder = ['Record liquidus / solidus readings here - ' ...
                'saved as <prefix>_Notes.txt on export and kept in session files.'];
            app.NotesTextArea.Tooltip = 'Free-text notes. Exported with the graphs and stored in sessions.';

            app.ExportGrid = uigridlayout(app.GraphsExportGrid);
            app.ExportGrid.ColumnWidth = {'fit', '1x', 'fit', 'fit', 'fit', 'fit'};
            app.ExportGrid.RowHeight = {'fit', 'fit'};
            app.ExportGrid.Layout.Row = 2;
            app.ExportGrid.Layout.Column = 1;

            app.ExportPathFieldLabel = uilabel(app.ExportGrid);
            app.ExportPathFieldLabel.Text = 'Export folder';
            app.ExportPathFieldLabel.Layout.Row = 1; app.ExportPathFieldLabel.Layout.Column = 1;

            app.ExportPathField = uieditfield(app.ExportGrid, 'text');
            app.ExportPathField.Editable = 'off';
            app.ExportPathField.Layout.Row = 1; app.ExportPathField.Layout.Column = 2;
            app.ExportPathField.Placeholder = 'No folder chosen';

            app.SetExportPathButton = uibutton(app.ExportGrid, 'push');
            app.SetExportPathButton.ButtonPushedFcn = createCallbackFcn(app, @SetExportPathButtonPushed, true);
            app.SetExportPathButton.Layout.Row = 1; app.SetExportPathButton.Layout.Column = 3;
            app.SetExportPathButton.Text = 'Set Export Path...';
            app.SetExportPathButton.Tooltip = 'Folder that exported graphs and notes are written into.';

            app.ExportButton = uibutton(app.ExportGrid, 'push');
            app.ExportButton.ButtonPushedFcn = createCallbackFcn(app, @ExportButtonPushed, true);
            app.ExportButton.Layout.Row = 1; app.ExportButton.Layout.Column = [4 6];
            app.ExportButton.Text = 'Export';
            app.ExportButton.FontWeight = 'bold';
            app.ExportButton.Tooltip = 'Export all five graphs (and notes) in the ticked formats.';

            app.ExportPrefixFieldLabel = uilabel(app.ExportGrid);
            app.ExportPrefixFieldLabel.Text = 'Filename prefix';
            app.ExportPrefixFieldLabel.Layout.Row = 2; app.ExportPrefixFieldLabel.Layout.Column = 1;

            app.ExportPrefixField = uieditfield(app.ExportGrid, 'text');
            app.ExportPrefixField.Layout.Row = 2; app.ExportPrefixField.Layout.Column = 2;
            app.ExportPrefixField.Placeholder = '(defaults to data-file name)';
            app.ExportPrefixField.Tooltip = 'Prefix for exported files, e.g. myalloy -> myalloy_1_cooling_curves.png';

            app.ExportTypeLabel = uilabel(app.ExportGrid);
            app.ExportTypeLabel.Text = 'Formats:';
            app.ExportTypeLabel.Layout.Row = 2; app.ExportTypeLabel.Layout.Column = 3;

            app.PNGCheckBox = uicheckbox(app.ExportGrid);
            app.PNGCheckBox.Text = 'PNG';
            app.PNGCheckBox.Value = true;
            app.PNGCheckBox.Layout.Row = 2; app.PNGCheckBox.Layout.Column = 4;

            app.JPEGCheckBox = uicheckbox(app.ExportGrid);
            app.JPEGCheckBox.Text = 'JPEG';
            app.JPEGCheckBox.Layout.Row = 2; app.JPEGCheckBox.Layout.Column = 5;

            app.PDFCheckBox = uicheckbox(app.ExportGrid);
            app.PDFCheckBox.Text = 'PDF';
            app.PDFCheckBox.Layout.Row = 2; app.PDFCheckBox.Layout.Column = 6;

            % ============================================================
            % Tab 2: Phase Diagram Construction
            % ============================================================
            app.PhaseDiagramTab = uitab(app.TabGroup);
            app.PhaseDiagramTab.Title = 'Phase Diagram Construction';

            app.PhaseGrid = uigridlayout(app.PhaseDiagramTab, [1 2]);
            app.PhaseGrid.ColumnWidth = {'1x', '1.4x'};
            app.PhaseGrid.RowHeight = {'1x'};

            app.PhaseDataPanel = uipanel(app.PhaseGrid);
            app.PhaseDataPanel.Title = 'Transformation Temperatures';
            app.PhaseDataPanel.Layout.Row = 1;
            app.PhaseDataPanel.Layout.Column = 1;

            app.PhaseDataGrid = uigridlayout(app.PhaseDataPanel);
            app.PhaseDataGrid.ColumnWidth = {'1x', '1x', '1x'};
            app.PhaseDataGrid.RowHeight = {'fit', '1x', 'fit', 'fit'};

            app.ImportTableDataButton = uibutton(app.PhaseDataGrid, 'push');
            app.ImportTableDataButton.ButtonPushedFcn = createCallbackFcn(app, @ImportTableDataButtonPushed, true);
            app.ImportTableDataButton.Layout.Row = 1; app.ImportTableDataButton.Layout.Column = 1;
            app.ImportTableDataButton.Text = 'Import Table Data...';
            app.ImportTableDataButton.Tooltip = ['Load composition / liquidus / solidus columns from ' ...
                'CSV or Excel. Columns are matched by header names where possible.'];

            app.AddNewRowButton = uibutton(app.PhaseDataGrid, 'push');
            app.AddNewRowButton.ButtonPushedFcn = createCallbackFcn(app, @AddNewRowButtonPushed, true);
            app.AddNewRowButton.Layout.Row = 1; app.AddNewRowButton.Layout.Column = 2;
            app.AddNewRowButton.Text = 'Add New Row';
            app.AddNewRowButton.Tooltip = 'Append an empty row; double-click cells to edit values.';

            app.DeleteRowButton = uibutton(app.PhaseDataGrid, 'push');
            app.DeleteRowButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteRowButtonPushed, true);
            app.DeleteRowButton.Layout.Row = 1; app.DeleteRowButton.Layout.Column = 3;
            app.DeleteRowButton.Text = 'Delete Selected';
            app.DeleteRowButton.Tooltip = 'Delete the currently selected row(s).';

            app.PhaseTable = uitable(app.PhaseDataGrid);
            app.PhaseTable.ColumnName = {'Composition', 'Liquidus', 'Solidus'};
            app.PhaseTable.ColumnEditable = [true true true];
            app.PhaseTable.RowName = 'numbered';
            app.PhaseTable.SelectionType = 'row';
            app.PhaseTable.Data = zeros(0, 3);
            app.PhaseTable.Layout.Row = 2; app.PhaseTable.Layout.Column = [1 3];
            app.PhaseTable.Tooltip = ['One row per alloy composition: composition value, liquidus ' ...
                'temperature, solidus temperature (from the Analysis tab).'];

            app.CompositionLabelFieldLabel = uilabel(app.PhaseDataGrid);
            app.CompositionLabelFieldLabel.Text = 'Composition axis label';
            app.CompositionLabelFieldLabel.Layout.Row = 3; app.CompositionLabelFieldLabel.Layout.Column = 1;

            app.CompositionLabelField = uieditfield(app.PhaseDataGrid, 'text');
            app.CompositionLabelField.Value = 'Composition (wt.%)';
            app.CompositionLabelField.Layout.Row = 3; app.CompositionLabelField.Layout.Column = [2 3];
            app.CompositionLabelField.Tooltip = 'X-axis label of the phase diagram, e.g. "Sn content (wt.%)".';

            app.ExportTableDataButton = uibutton(app.PhaseDataGrid, 'push');
            app.ExportTableDataButton.ButtonPushedFcn = createCallbackFcn(app, @ExportTableDataButtonPushed, true);
            app.ExportTableDataButton.Layout.Row = 4; app.ExportTableDataButton.Layout.Column = [1 3];
            app.ExportTableDataButton.Text = 'Export Table Data...';
            app.ExportTableDataButton.Tooltip = 'Save the table as CSV or Excel.';

            app.PhasePlotPanel = uipanel(app.PhaseGrid);
            app.PhasePlotPanel.Title = 'Phase Diagram';
            app.PhasePlotPanel.Layout.Row = 1;
            app.PhasePlotPanel.Layout.Column = 2;

            app.PhasePlotGrid = uigridlayout(app.PhasePlotPanel, [2 1]);
            app.PhasePlotGrid.RowHeight = {'1x', 'fit'};

            app.UIAxes6 = uiaxes(app.PhasePlotGrid);
            title(app.UIAxes6, 'Phase diagram');
            app.UIAxes6.Layout.Row = 1; app.UIAxes6.Layout.Column = 1;

            app.PhaseButtonsGrid = uigridlayout(app.PhasePlotGrid, [1 2]);
            app.PhaseButtonsGrid.Padding = [0 0 0 0];
            app.PhaseButtonsGrid.Layout.Row = 2; app.PhaseButtonsGrid.Layout.Column = 1;

            app.PlotPhaseDiagramButton = uibutton(app.PhaseButtonsGrid, 'push');
            app.PlotPhaseDiagramButton.ButtonPushedFcn = createCallbackFcn(app, @PlotPhaseDiagramButtonPushed, true);
            app.PlotPhaseDiagramButton.Layout.Row = 1; app.PlotPhaseDiagramButton.Layout.Column = 1;
            app.PlotPhaseDiagramButton.Text = 'Plot Phase Diagram';
            app.PlotPhaseDiagramButton.FontWeight = 'bold';
            app.PlotPhaseDiagramButton.Tooltip = 'Sort the table by composition and draw liquidus + solidus curves.';

            app.ExportGraphButton = uibutton(app.PhaseButtonsGrid, 'push');
            app.ExportGraphButton.ButtonPushedFcn = createCallbackFcn(app, @ExportGraphButtonPushed, true);
            app.ExportGraphButton.Layout.Row = 1; app.ExportGraphButton.Layout.Column = 2;
            app.ExportGraphButton.Text = 'Export Graph...';
            app.ExportGraphButton.Tooltip = 'Save the phase diagram as PNG, JPEG or PDF.';

            % ============================================================
            % Tab 3: About
            % ============================================================
            app.AboutTab = uitab(app.TabGroup);
            app.AboutTab.Title = 'About';

            app.AboutGrid = uigridlayout(app.AboutTab, [1 1]);

            app.AboutTextArea = uitextarea(app.AboutGrid);
            app.AboutTextArea.Editable = 'off';
            app.AboutTextArea.Layout.Row = 1; app.AboutTextArea.Layout.Column = 1;

            app.UIFigure.Visible = 'on';
        end
    end

    % ==================================================================
    % App creation and deletion
    % ==================================================================
    methods (Access = public)

        function app = ThermalAnalysisOfCoolingCurves
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
