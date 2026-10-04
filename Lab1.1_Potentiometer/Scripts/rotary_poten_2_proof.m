%% ROTARY_POTEN_2_PROOF Linear Proof for Rotary Poten 2 (10% to 95%)
%  Cuts 0%, 5%, and 100% deadband points and recalculates linearity across
%  the active electrical travel range (10% to 95%).
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
figDir   = fullfile(rootDir, 'Figures', 'Rotary Poten 2 Proof');   % proof plots are saved here only
repDir   = fullfile(rootDir, 'Results');

if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end

baseName = 'rotary_poten_2_proof';
outPng  = fullfile(figDir, sprintf('%s.png', baseName));
outFig  = fullfile(figDir, sprintf('%s.fig', baseName));
outXlsx = fullfile(repDir, sprintf('%s.xlsx', baseName));
outCsv  = fullfile(repDir, sprintf('%s_comparison.csv', baseName));

fprintf('========================================================================\n');
fprintf(' Rotary Poten 2 Proof: Linear Proof Analysis (10%% to 95%% Travel)\n');
fprintf('========================================================================\n');

% 1. Load active travel points from 10% to 95%
proof_points = (10:5:95)';
[datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir, 'Rotary Poten 2', proof_points);
nDatasets = numel(datasets);
nPoints   = height(comparisonTable);

fprintf('Successfully loaded %d datasets across %d active travel points (10%% to 95%%).\n', ...
    nDatasets, nPoints);
fprintf('Recalculated Linearity:\n');
fprintf('  - R^2: %.5f\n', metrics.R_Squared);
fprintf('  - Max Non-Linearity Error: %.2f%% FS (%.4f V)\n', ...
    metrics.MaxNonLinearity_pctFS, metrics.MaxNonLinearity_V);
fprintf('  - Sensitivity: %.2f mV/%%\n', metrics.Sensitivity_mV_per_mm);

% 2. Setup visualization
fig = figure('Color', 'w', 'Position', [100 100 860 560], ...
    'Name', 'Rotary Poten 2 Proof: Linear Proof');
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
title(ax, 'Rotary Poten 2 Proof: Rotational Travel (%) vs. Output Voltage', ...
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

% Add annotation box with recalculated sensor performance metrics
annotationText = sprintf(['\\bfRotary Poten 2 Proof\\rm\n', ...
    'Active Travel: 10%% to 95%% (85%%)\n', ...
    'Full Scale Output: %.2f V\n', ...
    'Sensitivity: %.2f mV/%%\n', ...
    '\\bfRecalculated R^2: %.5f\\rm\n', ...
    '\\bfMax Linearity Error: %.2f%% FS\\rm (%.3f V)\n', ...
    'Inter-Sweep Correlation: r = %.4f'], ...
    metrics.FullScaleOutput_V, metrics.Sensitivity_mV_per_mm, ...
    metrics.R_Squared, metrics.MaxNonLinearity_pctFS, metrics.MaxNonLinearity_V, ...
    mean_r);

dim = [0.58 0.16 0.34 0.25];
annotation(fig, 'textbox', dim, 'String', annotationText, 'FitBoxToText', 'on', ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
    'FontSize', 9.5, 'Margin', 5);

hold(ax, 'off');
drawnow;

% 3. Export publication figure
exportgraphics(fig, outPng, 'Resolution', 600);
savefig(fig, outFig);
fprintf('Saved main figure to:\n  - %s\n', outPng);

% Also generate individual sweep figures
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
    
    xlabel(ax_k, 'Rotational Travel (%)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax_k, 'Output Voltage (V)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax_k, sprintf('Rotary Poten 2 Proof: Travel (%%) vs. Voltage (%s)', datasets(k).name), ...
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
    'Total Evaluated Active Points';
    'Active Travel Range (%)';
    'Active Travel Span (%)';
    'Number of Experimental Datasets';
    'Full Scale Output (V)';
    'Full Scale Output (mV)';
    'Sensitivity (mV/%)';
    'Linear Model (R^2)';
    'Max Non-Linearity Error (% FS)';
    'Max Non-Linearity Error (V)';
    'Average Inter-Sweep Correlation (r)';
    'Mean Delta across Sweeps (mV)';
    'Maximum Delta across Sweeps (mV)'
};

metricsValues = {
    nPoints;
    '10% to 95%';
    85;
    metrics.NumDatasets;
    metrics.FullScaleOutput_V;
    metrics.FullScaleOutput_mV;
    metrics.Sensitivity_mV_per_mm;
    metrics.R_Squared;
    metrics.MaxNonLinearity_pctFS;
    metrics.MaxNonLinearity_V;
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
fprintf('\nRotary Poten 2 Proof complete!\n');
