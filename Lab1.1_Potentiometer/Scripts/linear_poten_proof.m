%% LINEAR_POTEN_PROOF Deadband Proof Analysis for Linear Poten 2
%  Cuts d = 0 and d = 60 mm and replaces them with d = 3 mm and d = 57 mm,
%  then recalculates sensor linearity across the active electrical stroke.
%
% Compatible with MATLAB R2020a through R2026a and MATLAB Agentic AI Toolkit.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir)
    thisDir = pwd;
end
if endsWith(thisDir, 'Scripts')
    rootDir = fileparts(thisDir);
else
    rootDir = thisDir;
end
figDir   = fullfile(rootDir, 'Figures', 'Linear Poten Proof');   % proof plots are saved here only
repDir   = fullfile(rootDir, 'Results');

if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end

baseName = 'linear_poten_proof';
outPng  = fullfile(figDir, sprintf('%s.png', baseName));
outFig  = fullfile(figDir, sprintf('%s.fig', baseName));
outXlsx = fullfile(repDir, sprintf('%s.xlsx', baseName));
outCsv  = fullfile(repDir, sprintf('%s_comparison.csv', baseName));

fprintf('========================================================================\n');
fprintf(' Linear Poten Proof: Deadband Removal (3 mm to 57 mm) Analysis\n');
fprintf('========================================================================\n');

% 1. Load Linear Poten 2 with d=0 and d=60 replaced by 3mm and 57mm
proof_dists = [3, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 57]';
[datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir, 'Linear Poten 2', proof_dists);
nDatasets = numel(datasets);
nPoints   = height(comparisonTable);

fprintf('Successfully loaded %d datasets across %d active test points (3 to 57 mm).\n', ...
    nDatasets, nPoints);
fprintf('Recalculated Linearity:\n');
fprintf('  - R^2: %.5f\n', metrics.R_Squared);
fprintf('  - Max Non-Linearity Error: %.2f%% FS (%.4f V)\n', ...
    metrics.MaxNonLinearity_pctFS, metrics.MaxNonLinearity_V);
fprintf('  - Sensitivity: %.2f mV/mm\n', metrics.Sensitivity_mV_per_mm);

% 2. Setup visualization
fig = figure('Color', 'w', 'Position', [100 100 860 560], ...
    'Name', 'Linear Poten Proof: Deadband Removal');
set(fig, 'DefaultTextInterpreter', 'tex', ...
         'DefaultAxesTickLabelInterpreter', 'tex', ...
         'DefaultLegendInterpreter', 'tex');

ax = axes(fig);
hold(ax, 'on');
set(ax, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
grid(ax, 'on');

% Color palette for sweeps
sweepColors = [
    0.12 0.45 0.80;  % Vivid Blue (Sweep 1)
    0.85 0.22 0.18;  % Coral Red (Sweep 2)
    0.15 0.62 0.32;  % Forest Green (Sweep 3)
];
markers = {'o', 's', '^'};

d_pct = comparisonTable.Distance_pct;
vMean = comparisonTable.Mean_V;

pale = @(c, w) c * (1 - w) + w;

% 1. Plot individual sweeps with transparent lines, markers, and error bars
h_sweeps = gobjects(nDatasets, 1);
for k = 1:nDatasets
    c = sweepColors(k, :);
    m = markers{k};
    vSweep = datasets(k).statsTable.Mean_Voltage_V;
    vStd   = datasets(k).statsTable.Std_Voltage_V;
    
    lineColor = pale(c, 0.55);
    
    % Connecting line with transparent appearance
    plot(ax, d_pct, vSweep, '-', 'Color', lineColor, 'LineWidth', 1.4, ...
        'HandleVisibility', 'off');
    
    % Error bars
    errorbar(ax, d_pct, vSweep, vStd, 'LineStyle', 'none', 'LineWidth', 0.8, ...
        'CapSize', 3.0, 'Color', pale(c, 0.50), 'HandleVisibility', 'off');
    
    % Semi-transparent scatter points
    scatter(ax, d_pct, vSweep, 55, m, 'filled', ...
        'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.75, ...
        'MarkerFaceAlpha', 0.65, 'MarkerEdgeAlpha', 0.85, ...
        'HandleVisibility', 'off');
    
    % Handle for legend displaying both marker and line
    h_sweeps(k) = plot(ax, nan, nan, ['-', m], 'Color', lineColor, 'LineWidth', 1.4, ...
        'MarkerSize', 6.5, 'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.75, ...
        'DisplayName', datasets(k).name);
end

% 2. Plot Mean curve as a bold dashed line placed ON TOP of everything
h_mean = plot(ax, d_pct, vMean, '--', 'Color', [0.12 0.12 0.15], 'LineWidth', 2.0, ...
    'DisplayName', 'Mean');

% Bring Mean dashed line to the top layer
uistack(h_mean, 'top');

% Formatting and labels
xlabel(ax, 'Displacement / Distance (%)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'Output Voltage (V)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'Linear Poten Proof: Distance (%) vs. Output Voltage', ...
    'FontSize', 13, 'FontWeight', 'bold');

xlim(ax, [-3 103]);
ylim(ax, [-0.1 3.5]);
xticks(ax, 0:10:100);
yticks(ax, 0:0.5:3.5);

legend(ax, [h_sweeps; h_mean], 'Location', 'northwest', 'FontSize', 10, 'Box', 'on');

% Add annotation box with recalculated sensor performance metrics
annotationText = sprintf(['\\bfLinear Poten Proof\\rm\n', ...
    'Active Travel: 3 mm - 57 mm (54 mm)\n', ...
    'Full Scale Output: %.2f V\n', ...
    'Sensitivity: %.2f mV/mm\n', ...
    '\\bfRecalculated R^2: %.5f\\rm\n', ...
    '\\bfMax Linearity Error: %.2f%% FS\\rm (%.3f V)'], ...
    metrics.FullScaleOutput_V, metrics.Sensitivity_mV_per_mm, ...
    metrics.R_Squared, metrics.MaxNonLinearity_pctFS, metrics.MaxNonLinearity_V);

dim = [0.58 0.16 0.31 0.22];
annotation(fig, 'textbox', dim, 'String', annotationText, 'FitBoxToText', 'on', ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
    'FontSize', 9.5, 'Margin', 5);

hold(ax, 'off');
drawnow;

% 3. Export publication figure
exportgraphics(fig, outPng, 'Resolution', 600);
savefig(fig, outFig);
fprintf('Saved main figure to:\n  - %s\n', outPng);

% Also generate individual sweep figures in Figures folder
fprintf('Generating individual sweep figures in Figures folders...\n');
for k = 1:nDatasets
    fig_k = figure('Color', 'w', 'Position', [120 120 720 480], 'Visible', 'off');
    set(fig_k, 'DefaultTextInterpreter', 'tex', ...
               'DefaultAxesTickLabelInterpreter', 'tex', ...
               'DefaultLegendInterpreter', 'tex');
    ax_k = axes(fig_k);
    hold(ax_k, 'on');
    set(ax_k, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
    grid(ax_k, 'on');
    
    c = sweepColors(k, :);
    m = markers{k};
    vSweep = datasets(k).statsTable.Mean_Voltage_V;
    vStd   = datasets(k).statsTable.Std_Voltage_V;
    
    errorbar(ax_k, d_pct, vSweep, vStd, 'LineStyle', 'none', 'LineWidth', 0.9, ...
        'CapSize', 3.5, 'Color', c * 0.6 + 0.4, 'HandleVisibility', 'off');
    plot(ax_k, d_pct, vSweep, ['-', m], 'Color', c, 'LineWidth', 1.5, ...
        'MarkerSize', 7, 'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.70, ...
        'DisplayName', datasets(k).name);
    
    xlabel(ax_k, 'Displacement / Distance (%)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax_k, 'Output Voltage (V)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax_k, sprintf('Linear Poten Proof: Distance (%%) vs. Voltage (%s)', datasets(k).name), ...
        'FontSize', 12, 'FontWeight', 'bold');
    xlim(ax_k, [-3 103]);
    ylim(ax_k, [-0.1 3.5]);
    xticks(ax_k, 0:10:100);
    yticks(ax_k, 0:0.5:3.5);
    legend(ax_k, 'Location', 'northwest', 'FontSize', 10, 'Box', 'on');
    
    sweepPng = fullfile(figDir, sprintf('%s_sweep%d.png', baseName, k));
    sweepFig = fullfile(figDir, sprintf('%s_sweep%d.fig', baseName, k));
    exportgraphics(fig_k, sweepPng, 'Resolution', 600);
    savefig(fig_k, sweepFig);
    close(fig_k);
    fprintf('  - %s\n', sweepPng);
end

% 4. Export comprehensive comparative Excel report in reports folder
fprintf('\nGenerating Excel statistical comparison workbook in reports folder...\n');

metricsNames = {
    'Stroke Nominal Reference (mm)';
    'Active Electrical Stroke Range (mm)';
    'Total Distance Evaluated Points';
    'Number of Experimental Datasets';
    'Full Scale Output (V)';
    'Full Scale Output (mV)';
    'Sensitivity (mV/mm)';
    'Linear Fit Slope (V/%)';
    'Linear Fit Intercept (V)';
    'Coefficient of Determination (R^2)';
    'Maximum Non-Linearity Error (V)';
    'Maximum Non-Linearity Error (% FSO)'
};

metricsValues = [
    metrics.MaxStroke_mm;
    metrics.ActiveStroke_mm;
    nPoints;
    metrics.NumDatasets;
    metrics.FullScaleOutput_V;
    metrics.FullScaleOutput_mV;
    metrics.Sensitivity_mV_per_mm;
    metrics.LinearSlope_V_per_pct;
    metrics.LinearIntercept_V;
    metrics.R_Squared;
    metrics.MaxNonLinearity_V;
    metrics.MaxNonLinearity_pctFS
];

metricsTable = table(metricsNames, metricsValues, ...
    'VariableNames', {'Characteristic', 'Value'});

% Write sheets to Excel file
if exist(outXlsx, 'file'), delete(outXlsx); end
writetable(comparisonTable, outXlsx, 'Sheet', 'Comparison_Summary');

for k = 1:nDatasets
    sheetName = sprintf('Dataset_%d_Sweep_%d', k, k);
    writetable(datasets(k).statsTable, outXlsx, 'Sheet', sheetName);
end

writetable(metricsTable, outXlsx, 'Sheet', 'Sensor_Characteristics');
writetable(comparisonTable, outCsv);

fprintf('Saved statistical comparison report to:\n  - %s\n  - %s\n', outXlsx, outCsv);
fprintf('\nLinear Poten Proof analysis complete!\n');
