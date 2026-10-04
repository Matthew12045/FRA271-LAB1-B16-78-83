%% ROTARY_POTEN_2 Plot Rotational Travel (%) vs Output Voltage for Rotary Poten 2 sweeps
%  and generate comparative statistical Excel report in the reports folder.
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
figDir  = fullfile(rootDir, 'Figures', 'Rotary Poten 2');
repDir  = fullfile(rootDir, 'Results');

if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end

baseName = 'rotary_poten_2';
outPng  = fullfile(figDir, sprintf('%s.png', baseName));
outFig  = fullfile(figDir, sprintf('%s.fig', baseName));
outXlsx = fullfile(repDir, sprintf('%s.xlsx', baseName));
outCsv  = fullfile(repDir, sprintf('%s_comparison.csv', baseName));

fprintf('========================================================================\n');
fprintf(' Rotary Potentiometer 2: Rotational Travel (%%) vs. Output Voltage Analysis\n');
fprintf('========================================================================\n');

% 1. Load and process datasets
[datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir, 'Rotary Poten 2');
nDatasets = numel(datasets);
nPoints   = height(comparisonTable);
fprintf('Successfully loaded %d datasets across %d travel points (0%% to 100%%).\n', ...
    nDatasets, nPoints);

% 2. Setup visualization
fig = figure('Color', 'w', 'Position', [100 100 860 560], ...
    'Name', 'Rotary Potentiometer 2: travel vs voltage');
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
    
    % Connecting line
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
    
    % Legend handle
    h_sweeps(k) = plot(ax, nan, nan, ['-', m], 'Color', lineColor, 'LineWidth', 1.4, ...
        'MarkerSize', 6.5, 'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.75, ...
        'DisplayName', datasets(k).name);
end

% 2. Plot Mean curve as a bold dashed line placed ON TOP of everything
h_mean = plot(ax, d_pct, vMean, '--', 'Color', [0.12 0.12 0.15], 'LineWidth', 2.0, ...
    'DisplayName', 'Mean');

uistack(h_mean, 'top');

% Formatting and labels
xlabel(ax, 'Rotational Travel (%)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'Output Voltage (V)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'Rotary Potentiometer 2: Rotational Travel (%) vs. Output Voltage', ...
    'FontSize', 13, 'FontWeight', 'bold');

xlim(ax, [-3 103]);
ylim(ax, [-0.1 3.5]);
xticks(ax, 0:10:100);
yticks(ax, 0:0.5:3.5);

legend(ax, [h_sweeps; h_mean], 'Location', 'northwest', 'FontSize', 10, 'Box', 'on');

% Dynamic multi-sweep calculations
V_mat = zeros(nPoints, nDatasets);
for k = 1:nDatasets
    V_mat(:, k) = datasets(k).statsTable.Mean_Voltage_V;
end
R_corr = corrcoef(V_mat);
corr_pairs = [];
for i_c = 1:nDatasets
    for j_c = (i_c+1):nDatasets
        corr_pairs(end+1) = R_corr(i_c, j_c); %#ok<AGROW>
    end
end
mean_r = mean(corr_pairs);
mean_delta_mV = mean(comparisonTable.Max_Delta_mV);
max_delta_mV  = max(comparisonTable.Max_Delta_mV);
v50 = vMean(d_pct == 50);
pct_fso_50 = (v50 / metrics.FullScaleOutput_V) * 100;

% Add annotation box with sensor performance metrics (same layout for all five potentiometers)
annotationText = sprintf(['\\bfRotary Potentiometer 2 Characteristics\\rm\n', ...
    'Full Scale Output: %.2f V\n', ...
    'Output at 50%% Travel: %.2f V (%.1f%% FS)\n', ...
    'R^2 (Linear Fit): %.4f\n', ...
    'Max Linearity Error: %.1f%% FS'], ...
    metrics.FullScaleOutput_V, v50, 100 * v50 / metrics.FullScaleOutput_V, ...
    metrics.R_Squared, metrics.MaxNonLinearity_pctFS);

hAnn = annotation(fig, 'textbox', [0 0 0.1 0.1], 'String', annotationText, 'FitBoxToText', 'on', ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
    'FontSize', 9.5, 'Margin', 5);
% Pin the fitted box inside the bottom-right corner of the axes frame
drawnow;
axPos  = ax.Position;
annPos = hAnn.Position;
pad    = 0.012;
hAnn.Position = [axPos(1) + axPos(3) - annPos(3) - pad, axPos(2) + 1.5 * pad, annPos(3), annPos(4)];

hold(ax, 'off');
drawnow;

% 3. Export publication figure
exportgraphics(fig, outPng, 'Resolution', 600);
savefig(fig, outFig);
fprintf('Saved main figure to Figures folder:\n  - %s\n  - %s\n', outPng, outFig);

% Also generate individual sweep figures
fprintf('Generating individual sweep figures in Figures folder...\n');
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
    
    xlabel(ax_k, 'Rotational Travel (%)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax_k, 'Output Voltage (V)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax_k, sprintf('Rotary Potentiometer 2: Travel (%%) vs. Voltage (%s)', datasets(k).name), ...
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
    'Total Evaluated Points';
    'Number of Experimental Datasets';
    'Full Scale Output (V)';
    'Full Scale Output (mV)';
    'Output Voltage at 50% Travel (V)';
    'Output Voltage at 50% Travel (% FSO)';
    'Taper Classification';
    'Linear Model (R^2)';
    'Max Non-Linearity Error (% FS)';
    'Max Non-Linearity Error (V)';
    'Sensitivity (mV/%)';
    'Average Inter-Sweep Correlation (r)';
    'Mean Delta across Sweeps (mV)';
    'Maximum Delta across Sweeps (mV)'
};

metricsValues = {
    nPoints;
    metrics.NumDatasets;
    metrics.FullScaleOutput_V;
    metrics.FullScaleOutput_mV;
    v50;
    pct_fso_50;
    'B-Series (Linear Taper)';
    metrics.R_Squared;
    metrics.MaxNonLinearity_pctFS;
    metrics.MaxNonLinearity_V;
    metrics.Sensitivity_mV_per_mm;
    mean_r;
    mean_delta_mV;
    max_delta_mV
};

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
fprintf('\nRotary Poten 2 analysis complete!\n');
