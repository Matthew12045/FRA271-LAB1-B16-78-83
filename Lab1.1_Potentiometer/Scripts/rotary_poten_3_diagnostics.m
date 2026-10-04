%% ROTARY_POTEN_3_DIAGNOSTICS Independent Calibration & Residual Diagnostics Analysis
%  Generates a publication-grade two-panel diagnostic figure (voltage fit & residuals),
%  computes mean, pooled, and per-sweep OLS fits, evaluates interval-average sensitivities,
%  runs the formal ANOVA lack-of-fit test, and exports dedicated diagnostic reports.
%
% This script leaves the legacy rotary_poten_3.m and rotary_poten_3.png untouched,
% outputting rotary_poten_3_diagnostics.png (.fig), rotary_poten_3_diagnostics.xlsx,
% and rotary_poten_3_diagnostics_comparison.csv.
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
figDir  = fullfile(rootDir, 'Figures', 'Rotary Poten 3');
repDir  = fullfile(rootDir, 'Results');

if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end

baseName = 'rotary_poten_3_diagnostics';
outPng  = fullfile(figDir, sprintf('%s.png', baseName));
outFig  = fullfile(figDir, sprintf('%s.fig', baseName));
outXlsx = fullfile(repDir, sprintf('%s.xlsx', baseName));
outCsv  = fullfile(repDir, sprintf('%s_comparison.csv', baseName));

fprintf('========================================================================\n');
fprintf(' Rotary Potentiometer 3: Calibration & Residual Diagnostics\n');
fprintf('========================================================================\n');

% 1. Load and process datasets
[datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir, 'Rotary Poten 3');
nDatasets = numel(datasets);
nPoints   = height(comparisonTable);
fprintf('Successfully loaded %d datasets across %d travel points (0%% to 100%%).\n', ...
    nDatasets, nPoints);

d_pct = comparisonTable.Distance_pct;
vMean = comparisonTable.Mean_V;

% 2. Independent Straight-Line Fits (Full 0–100% Range, V = a*x + b)

% A. Mean-Curve OLS Fit
p_mean = polyfit(d_pct, vMean, 1);
vFit_mean = polyval(p_mean, d_pct);
res_mean = vMean - vFit_mean;
SSE_mean = sum(res_mean.^2);
SST_mean = sum((vMean - mean(vMean)).^2);
R2_mean  = 1 - SSE_mean / SST_mean;
RMSE_mean_df = sqrt(SSE_mean / (nPoints - 2)); % df = 19 denominator
RMSE_mean_N  = sqrt(SSE_mean / nPoints);        % N = 21 denominator
FS_mean = max(vMean) - min(vMean);             % Explicitly max(Vmean) - min(Vmean)
[max_res_mean, max_idx_mean] = max(abs(res_mean));
max_pos_mean = d_pct(max_idx_mean);
lin_err_mean = 100 * max_res_mean / FS_mean;

% B. Pooled OLS Fit (All 63 Observations)
x_pooled = repmat(d_pct, nDatasets, 1);
y_pooled = zeros(nPoints * nDatasets, 1);
for k = 1:nDatasets
    idx_k = (k-1)*nPoints + (1:nPoints);
    y_pooled(idx_k) = datasets(k).statsTable.Mean_Voltage_V;
end
p_pooled = polyfit(x_pooled, y_pooled, 1);
vFit_pooled = polyval(p_pooled, x_pooled);
res_pooled = y_pooled - vFit_pooled;
SSE_pooled = sum(res_pooled.^2);
SST_pooled = sum((y_pooled - mean(y_pooled)).^2);
R2_pooled  = 1 - SSE_pooled / SST_pooled;
RMSE_pooled_df = sqrt(SSE_pooled / (numel(y_pooled) - 2)); % df = 61 denominator
RMSE_pooled_N  = sqrt(SSE_pooled / numel(y_pooled));        % N = 63 denominator
max_res_pooled = max(abs(res_pooled));
lin_err_pooled = 100 * max_res_pooled / FS_mean;

% C. Individual Per-Sweep Fits
sweepFits = struct('p', {}, 'R2', {}, 'SSE', {}, 'SST', {}, ...
    'RMSE_df', {}, 'RMSE_N', {}, 'FS', {}, 'MaxRes', {}, 'LinErr', {});
for k = 1:nDatasets
    y_k = datasets(k).statsTable.Mean_Voltage_V;
    p_k = polyfit(d_pct, y_k, 1);
    vFit_k = polyval(p_k, d_pct);
    res_k = y_k - vFit_k;
    sse_k = sum(res_k.^2);
    sst_k = sum((y_k - mean(y_k)).^2);
    fs_k  = max(y_k) - min(y_k);
    max_res_k = max(abs(res_k));
    sweepFits(k).p = p_k;
    sweepFits(k).R2 = 1 - sse_k / sst_k;
    sweepFits(k).SSE = sse_k;
    sweepFits(k).SST = sst_k;
    sweepFits(k).RMSE_df = sqrt(sse_k / (nPoints - 2));
    sweepFits(k).RMSE_N  = sqrt(sse_k / nPoints);
    sweepFits(k).FS = fs_k;
    sweepFits(k).MaxRes = max_res_k;
    sweepFits(k).LinErr = 100 * max_res_k / fs_k;
end

% 3. Interval-Average Sensitivities
idx10 = find(d_pct == 10, 1);
idx40 = find(d_pct == 40, 1);
idx45 = find(d_pct == 45, 1);
idx90 = find(d_pct == 90, 1);

sens_10_40_mV_per_pct = 1000 * (vMean(idx40) - vMean(idx10)) / (d_pct(idx40) - d_pct(idx10));
sens_45_90_mV_per_pct = 1000 * (vMean(idx90) - vMean(idx45)) / (d_pct(idx90) - d_pct(idx45));
sens_ratio_10_40_to_45_90 = sens_10_40_mV_per_pct / sens_45_90_mV_per_pct;
endpoint_sens_mV_per_pct = 1000 * FS_mean / (max(d_pct) - min(d_pct));

% 4. Formal Lack-of-Fit Test (ANOVA)
y_mat = zeros(nPoints, nDatasets);
for k = 1:nDatasets
    y_mat(:, k) = datasets(k).statsTable.Mean_Voltage_V;
end
SS_PE  = sum(sum((y_mat - vMean).^2));
SS_LOF = sum(nDatasets * (vMean - vFit_mean).^2);
df_LOF = nPoints - 2;                      % 21 - 2 = 19
df_PE  = nPoints * nDatasets - nPoints;    % 63 - 21 = 42
MS_LOF = SS_LOF / df_LOF;
MS_PE  = SS_PE / df_PE;
F_stat = MS_LOF / MS_PE;
z_f = df_PE / (df_PE + df_LOF * F_stat);
p_val_LOF = betainc(z_f, df_PE/2, df_LOF/2); % Upper-tail p-value via regularized incomplete beta

% 5. Inter-Sweep Agreement and Variation
R_corr = corrcoef(y_mat);
corr_pairs = [];
for i_c = 1:nDatasets
    for j_c = (i_c+1):nDatasets
        corr_pairs(end+1) = R_corr(i_c, j_c); %#ok<AGROW>
    end
end
mean_r = mean(corr_pairs);
mean_delta_mV = mean(comparisonTable.Max_Delta_mV);
[max_delta_mV, max_delta_idx] = max(comparisonTable.Max_Delta_mV);
max_delta_pos = d_pct(max_delta_idx);

v50 = vMean(d_pct == 50);
pct_fso_50 = (v50 / FS_mean) * 100;

% 6. Numerical Consistency Checks
assert(abs(p_mean(1) - p_pooled(1)) < 1e-12, 'Slope mismatch: mean curve vs. pooled fit');
assert(abs(p_mean(2) - p_pooled(2)) < 1e-12, 'Intercept mismatch: mean curve vs. pooled fit');
assert(abs((SS_PE + SS_LOF) - SSE_pooled) < 1e-10, 'ANOVA identity SS_PE + SS_LOF == SSE_pooled violated');
assert(max_pos_mean == 40, 'Max absolute residual position must be 40%% travel');

fprintf('Independent verification:\n');
fprintf('  - Mean curve fit:  V = %.6f*x + %.6f V | R^2 = %.5f | Lin Err = %.2f%% FS\n', ...
    p_mean(1), p_mean(2), R2_mean, lin_err_mean);
fprintf('  - Pooled fit:      V = %.6f*x + %.6f V | R^2 = %.5f | Lin Err = %.2f%% FS\n', ...
    p_pooled(1), p_pooled(2), R2_pooled, lin_err_pooled);
fprintf('  - Lack-of-Fit F:   F = %.2f (df = %d, %d), p = %.2e\n', ...
    F_stat, df_LOF, df_PE, p_val_LOF);
fprintf('  - Sensitivities:   10-40%% = %.2f mV/%%, 45-90%% = %.2f mV/%% (Ratio: %.2f:1)\n', ...
    sens_10_40_mV_per_pct, sens_45_90_mV_per_pct, sens_ratio_10_40_to_45_90);
fprintf('  - Consistency:     ANOVA decomposition verified (|SSE_pooled - (SS_PE+SS_LOF)| < 1e-10).\n\n');

% 7. Generate Two-Panel Publication Diagnostic Figure
fig = figure('Color', 'w', 'Position', [100 60 980 780], ...
    'Name', 'Rotary Potentiometer 3: Calibration and Residual Diagnostics');
set(fig, 'DefaultTextInterpreter', 'tex', ...
         'DefaultAxesTickLabelInterpreter', 'tex', ...
         'DefaultLegendInterpreter', 'tex');

sweepColors = [
    0.12 0.45 0.80;  % Vivid Blue (Sweep 1)
    0.85 0.22 0.18;  % Coral Red (Sweep 2)
    0.15 0.62 0.32;  % Forest Green (Sweep 3)
];
markers = {'o', 's', '^'};
pale = @(c, w) c * (1 - w) + w;

% TOP PANEL: Output Voltage vs Travel
ax1 = subplot(2, 1, 1);
hold(ax1, 'on');
set(ax1, 'FontSize', 10.5, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
grid(ax1, 'on');

h_sweeps = gobjects(nDatasets, 1);
for k = 1:nDatasets
    c = sweepColors(k, :);
    m = markers{k};
    vSweep = datasets(k).statsTable.Mean_Voltage_V;
    vStd   = datasets(k).statsTable.Std_Voltage_V;
    lineColor = pale(c, 0.55);
    
    plot(ax1, d_pct, vSweep, '-', 'Color', lineColor, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
    errorbar(ax1, d_pct, vSweep, vStd, 'LineStyle', 'none', 'LineWidth', 0.8, ...
        'CapSize', 3.0, 'Color', pale(c, 0.50), 'HandleVisibility', 'off');
    scatter(ax1, d_pct, vSweep, 45, m, 'filled', ...
        'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.75, ...
        'MarkerFaceAlpha', 0.65, 'MarkerEdgeAlpha', 0.85, ...
        'HandleVisibility', 'off');
    h_sweeps(k) = plot(ax1, nan, nan, ['-', m], 'Color', lineColor, 'LineWidth', 1.2, ...
        'MarkerSize', 6, 'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.75, ...
        'DisplayName', datasets(k).name);
end

% Mean curve
h_mean = plot(ax1, d_pct, vMean, '--', 'Color', [0.10 0.10 0.15], 'LineWidth', 2.0, ...
    'DisplayName', 'Mean Curve (Consensus Across Sweeps)');

% Fitted least-squares straight line
h_fit = plot(ax1, d_pct, vFit_mean, '-', 'Color', [0.75 0.05 0.45], 'LineWidth', 2.0, ...
    'DisplayName', sprintf('Least-Squares Line (V = %.4fx + %.4f V)', p_mean(1), p_mean(2)));

uistack(h_fit, 'top');
uistack(h_mean, 'top');

xlabel(ax1, 'Rotational Travel (%)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel(ax1, 'Output Voltage (V)', 'FontSize', 11, 'FontWeight', 'bold');
title(ax1, 'Rotary Potentiometer 3: Rotational Travel vs. Output Voltage and Linear Fit', ...
    'FontSize', 12, 'FontWeight', 'bold');
xlim(ax1, [-3 103]);
ylim(ax1, [-0.1 3.5]);
xticks(ax1, 0:10:100);
yticks(ax1, 0:0.5:3.5);

legend(ax1, [h_sweeps; h_mean; h_fit], 'Location', 'northwest', 'FontSize', 9, 'Box', 'on');

% Summary annotation textbox placed in open lower-right quadrant
annotText = sprintf(['\\bfRotary Potentiometer 3 Verified Performance\\rm\n', ...
    'Evaluated Travel Range: 0 to 100%% (N = 21 positions, 63 obs)\n', ...
    'Full Scale Span: FS = %.4f V [max(V_{mean}) - min(V_{mean})]\n', ...
    'Mean-Curve OLS Fit: \\bfV = %.5fx + %.4f V\\rm\n', ...
    'Fit Quality: \\bfR^2 = %.4f\\rm | RMSE = %.4f V (df=19) [%.4f V (N=21)]\n', ...
    'Max Linearity Error: \\bf%.2f%% FS\\rm (%.4f V at %g%% travel)\n', ...
    'Lack-of-Fit Test: \\bfF = %.1f\\rm (p = %.2e, df = 19, 42)\n', ...
    'Sensitivities: 10-40%%: %.2f mV/%% | 45-90%%: %.2f mV/%%\n', ...
    'Sensitivity Ratio (10-40%% / 45-90%%): \\bf%.2f : 1\\rm (Severe Nonlinearity)\n', ...
    'Midpoint Voltage (50%% travel): %.4f V (%.1f%% FS)\n', ...
    'Inter-Sweep Mean \\DeltaV: %.1f mV (Max: %.1f mV at %g%%) | r = %.4f'], ...
    FS_mean, p_mean(1), p_mean(2), ...
    R2_mean, RMSE_mean_df, RMSE_mean_N, ...
    lin_err_mean, max_res_mean, max_pos_mean, ...
    F_stat, p_val_LOF, ...
    sens_10_40_mV_per_pct, sens_45_90_mV_per_pct, ...
    sens_ratio_10_40_to_45_90, ...
    v50, pct_fso_50, ...
    mean_delta_mV, max_delta_mV, max_delta_pos, mean_r);

text(ax1, 48, 0.15, annotText, 'FontSize', 7.8, 'BackgroundColor', [0.97 0.97 0.98], ...
    'EdgeColor', [0.70 0.70 0.75], 'Margin', 4, 'VerticalAlignment', 'bottom');

% BOTTOM PANEL: Residual Diagnostics vs Travel
ax2 = subplot(2, 1, 2);
hold(ax2, 'on');
set(ax2, 'FontSize', 10.5, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
grid(ax2, 'on');

% Zero reference line
plot(ax2, [-5 105], [0 0], 'k-', 'LineWidth', 1.2, 'DisplayName', 'Zero Reference (V = V_{fit})');

% Sweep residuals
for k = 1:nDatasets
    c = sweepColors(k, :);
    m = markers{k};
    vSweep = datasets(k).statsTable.Mean_Voltage_V;
    resSweep = vSweep - vFit_mean;
    lineColor = pale(c, 0.40);
    plot(ax2, d_pct, resSweep, ':', 'Color', lineColor, 'LineWidth', 1.0, 'HandleVisibility', 'off');
    scatter(ax2, d_pct, resSweep, 38, m, 'filled', ...
        'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.70, ...
        'MarkerFaceAlpha', 0.65, 'MarkerEdgeAlpha', 0.85, ...
        'DisplayName', sprintf('Residuals: %s', datasets(k).name));
end

% Mean curve residuals
plot(ax2, d_pct, res_mean, 'k--o', 'LineWidth', 1.8, 'MarkerSize', 6.0, ...
    'MarkerFaceColor', [0.20 0.20 0.25], 'MarkerEdgeColor', 'k', ...
    'DisplayName', 'Residuals: Mean Curve (V_{mean} - V_{fit})');

% Mark peak residual at 40% travel
plot(ax2, max_pos_mean, res_mean(max_idx_mean), 'p', 'MarkerSize', 13, ...
    'MarkerFaceColor', [0.90 0.10 0.10], 'MarkerEdgeColor', 'k', 'LineWidth', 1.2, ...
    'DisplayName', sprintf('Peak Deviation: +%.4f V (+%.2f%% FS at %g%%)', ...
    res_mean(max_idx_mean), lin_err_mean, max_pos_mean));

xlabel(ax2, 'Rotational Travel (%)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel(ax2, 'Residual V - V_{fit} (V)', 'FontSize', 11, 'FontWeight', 'bold');
title(ax2, sprintf('Residual Diagnostics vs. Rotational Travel (Full-Scale Span FS = %.4f V)', FS_mean), ...
    'FontSize', 11.5, 'FontWeight', 'bold');
xlim(ax2, [-3 103]);
ylim(ax2, [-0.85 0.95]);
xticks(ax2, 0:10:100);
yticks(ax2, -0.8:0.2:0.9);

legend(ax2, 'Location', 'southwest', 'FontSize', 8.5, 'Box', 'on');

% Dual Right Axis for % FS
yyaxis(ax2, 'right');
ylim(ax2, [-0.85 0.95] / FS_mean * 100);
ylabel(ax2, 'Residual (% FS)', 'FontSize', 11, 'FontWeight', 'bold');
set(ax2, 'YColor', [0.25 0.25 0.30]);
yyaxis(ax2, 'left');

hold(ax1, 'off');
hold(ax2, 'off');
drawnow;

% Export two-panel publication figure
exportgraphics(fig, outPng, 'Resolution', 600);
savefig(fig, outFig);
fprintf('Saved two-panel diagnostic figure to Figures folder:\n  - %s\n  - %s\n', outPng, outFig);

% 8. Export Dedicated Diagnostic Excel Report & CSV
fprintf('\nGenerating dedicated diagnostic Excel workbook and CSV in reports folder...\n');

diagTable = comparisonTable;
diagTable.OLS_Fit_V           = vFit_mean;
diagTable.Residual_Mean_V     = res_mean;
diagTable.Residual_Mean_pctFS = (res_mean / FS_mean) * 100;

metricsNames = {
    'Total Evaluated Points';
    'Number of Experimental Datasets';
    'Total Replicate Observations';
    'Evaluated Travel Range (%)';
    'Full Scale Output Span FS (V)';
    'Full Scale Output Span FS (mV)';
    'Output Voltage at 50% Travel (V)';
    'Output Voltage at 50% Travel (% FS)';
    'Empirical Response Profile';
    'Mean-Curve OLS Fit Slope (V/%)';
    'Mean-Curve OLS Fit Slope (mV/%)';
    'Mean-Curve OLS Fit Intercept (V)';
    'Mean-Curve Fit SSE (V^2)';
    'Mean-Curve Fit SST (V^2)';
    'Mean-Curve Linear Fit (R^2)';
    'Mean-Curve RMSE [df=19 denominator] (V)';
    'Mean-Curve RMSE [N=21 denominator] (V)';
    'Mean-Curve Max Linearity Error (% FS)';
    'Mean-Curve Max Linearity Error (V)';
    'Position of Max Residual (%)';
    'Pooled OLS Fit Slope (mV/%)';
    'Pooled OLS Fit Intercept (V)';
    'Pooled Fit SSE (V^2)';
    'Pooled Fit SST (V^2)';
    'Pooled Fit (R^2)';
    'Pooled Fit RMSE [df=61 denominator] (V)';
    'Pooled Fit RMSE [N=63 denominator] (V)';
    'Pooled Max Linearity Error (% FS)';
    'Pooled Max Linearity Error (V)';
    'Average Endpoint Sensitivity (mV/%)';
    'Interval Sensitivity 10-40% Travel (mV/%)';
    'Interval Sensitivity 45-90% Travel (mV/%)';
    'Sensitivity Ratio (10-40% / 45-90%)';
    'Pure Error Sum of Squares SS_PE (V^2)';
    'Lack-of-Fit Sum of Squares SS_LOF (V^2)';
    'Lack-of-Fit Degrees of Freedom';
    'Pure Error Degrees of Freedom';
    'Lack-of-Fit F-Statistic';
    'Lack-of-Fit p-value';
    'Mean Delta across Sweeps (mV)';
    'Maximum Delta across Sweeps (mV)';
    'Position of Maximum Delta (%)';
    'Average Inter-Sweep Correlation (r)'
};

metricsValues = {
    nPoints;
    nDatasets;
    nPoints * nDatasets;
    '0 to 100%';
    FS_mean;
    FS_mean * 1000;
    v50;
    pct_fso_50;
    'Nonlinear (rapid initial rise, 85.3% FS at 50% midpoint, no verified manufacturer taper)';
    p_mean(1);
    p_mean(1) * 1000;
    p_mean(2);
    SSE_mean;
    SST_mean;
    R2_mean;
    RMSE_mean_df;
    RMSE_mean_N;
    lin_err_mean;
    max_res_mean;
    max_pos_mean;
    p_pooled(1) * 1000;
    p_pooled(2);
    SSE_pooled;
    SST_pooled;
    R2_pooled;
    RMSE_pooled_df;
    RMSE_pooled_N;
    lin_err_pooled;
    max_res_pooled;
    endpoint_sens_mV_per_pct;
    sens_10_40_mV_per_pct;
    sens_45_90_mV_per_pct;
    sens_ratio_10_40_to_45_90;
    SS_PE;
    SS_LOF;
    df_LOF;
    df_PE;
    F_stat;
    p_val_LOF;
    mean_delta_mV;
    max_delta_mV;
    max_delta_pos;
    mean_r
};

metricsTable = table(metricsNames, metricsValues, ...
    'VariableNames', {'Characteristic', 'Value'});

if exist(outXlsx, 'file'), delete(outXlsx); end
writetable(diagTable, outXlsx, 'Sheet', 'Diagnostic_Summary');
for k = 1:nDatasets
    sheetName = sprintf('Dataset_%d_Sweep_%d', k, k);
    writetable(datasets(k).statsTable, outXlsx, 'Sheet', sheetName);
end
writetable(metricsTable, outXlsx, 'Sheet', 'Sensor_Characteristics');
writetable(diagTable, outCsv);

fprintf('Saved diagnostic comparison report to:\n  - %s\n  - %s\n', outXlsx, outCsv);
fprintf('\nRotary Poten 3 diagnostic analysis complete and verified!\n');
