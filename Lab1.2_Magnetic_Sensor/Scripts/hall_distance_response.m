%% HALL_DISTANCE_RESPONSE Vout and B vs distance for each pole / shield condition.
%  One figure per condition: every unique sweep, the sweep mean, the datasheet
%  linear range VL, and a right-hand axis in mT from B = (Vout - VQ) / S.
%  Also writes the per-distance summary table used in the report.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end

H = load_hall_sweeps(rootDir);

cfg = {
    'North',    'North Pole, Unshielded', [0 1800],    'northwest'
    'North_Sh', 'North Pole, Shielded',   [0 1800],    'northwest'
    'South',    'South Pole, Unshielded', [1500 3400], 'northeast'
    'South_Sh', 'South Pole, Shielded',   [1500 3400], 'northeast'
};

summary = table();
for k = 1:size(cfg, 1)
    E = H.(cfg{k, 1});
    plot_condition(H, E, cfg{k, 2}, cfg{k, 3}, cfg{k, 4}, ...
        fullfile(figDir, sprintf('distance_response_%s', lower(cfg{k, 1}))));

    Vm = mean(E.V, 2);
    T = table(repmat(string(cfg{k, 1}), numel(H.d), 1), H.d, Vm, std(E.V, 0, 2), ...
        (Vm - H.VQ) / H.S, std(E.B, 0, 2), median(E.SD, 2), E.linear, ...
        'VariableNames', {'Condition', 'Distance_cm', 'Vmean_mV', 'Vstd_sweeps_mV', ...
                          'Bmean_mT', 'Bstd_sweeps_mT', 'Noise_sigma_mV', 'InsideVL'});
    summary = [summary; T]; %#ok<AGROW>
end
writetable(summary, fullfile(repDir, 'hall_distance_summary.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'hall_distance_summary.csv'));

%% ---------------------------------------------------------------- helpers
function plot_condition(H, E, ttl, ylimV, legLoc, outBase)
sweepColors = [
    0.12 0.45 0.80;  % Vivid Blue (Sweep 1)
    0.85 0.22 0.18;  % Coral Red (Sweep 2)
    0.15 0.62 0.32;  % Forest Green (Sweep 3)
    0.55 0.27 0.68;  % Purple (Sweep 4)
    0.90 0.55 0.10;  % Amber (Sweep 5)
];
markers = {'o', 's', '^', 'd', 'v'};
pale = @(c, w) c * (1 - w) + w;
d = H.d;
nS = size(E.V, 2);

fig = figure('Color', 'w', 'Position', [100 100 860 560], 'Name', ttl);
set(fig, 'DefaultTextInterpreter', 'tex', ...
         'DefaultAxesTickLabelInterpreter', 'tex', ...
         'DefaultLegendInterpreter', 'tex');
ax = axes(fig);
hold(ax, 'on');
set(ax, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
grid(ax, 'on');

% Shade the output range outside the datasheet linear range VL (saturation)
yyaxis(ax, 'left');
if ylimV(1) < H.VL(1)
    hBand = patch(ax, [0 4 4 0], [ylimV(1) ylimV(1) H.VL(1) H.VL(1)], [0.90 0.90 0.90], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.8);
    text(ax, 1.0, mean([ylimV(1) H.VL(1)]), 'Outside V_L (saturation)', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0.35 0.35 0.35]);
else
    hBand = patch(ax, [0 4 4 0], [H.VL(2) H.VL(2) ylimV(2) ylimV(2)], [0.90 0.90 0.90], ...
        'EdgeColor', 'none', 'FaceAlpha', 0.8);
    text(ax, 1.0, mean([H.VL(2) ylimV(2)]), 'Outside V_L (saturation)', ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'FontSize', 9.5, 'Color', [0.35 0.35 0.35]);
end
hBand.HandleVisibility = 'off';

hS = gobjects(nS, 1);
for k = 1:nS
    c = sweepColors(k, :);
    m = markers{k};
    lineColor = pale(c, 0.55);
    plot(ax, d, E.V(:, k), '-', 'Color', lineColor, 'LineWidth', 1.4, 'HandleVisibility', 'off');
    errorbar(ax, d, E.V(:, k), E.SD(:, k), 'LineStyle', 'none', 'LineWidth', 0.8, ...
        'CapSize', 3.0, 'Color', pale(c, 0.50), 'HandleVisibility', 'off');
    scatter(ax, d, E.V(:, k), 45, m, 'filled', ...
        'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.75, ...
        'MarkerFaceAlpha', 0.65, 'MarkerEdgeAlpha', 0.85, 'HandleVisibility', 'off');
    hS(k) = plot(ax, nan, nan, ['-', m], 'Color', lineColor, 'LineWidth', 1.4, ...
        'MarkerSize', 6.5, 'MarkerFaceColor', c, 'MarkerEdgeColor', c * 0.75, ...
        'DisplayName', E.sweeps{k});
end
Vm = mean(E.V, 2);
hM = plot(ax, d, Vm, '--', 'Color', [0.12 0.12 0.15], 'LineWidth', 2.0, 'DisplayName', 'Mean');
uistack(hM, 'top');

ylim(ax, ylimV);
ylabel(ax, 'Output Voltage V_{out} (mV)', 'FontSize', 12, 'FontWeight', 'bold');
ax.YAxis(1).Color = [0.15 0.15 0.15];

% Right axis: the same signal in mT, B = (Vout - VQ) / S
yyaxis(ax, 'right');
ylim(ax, (ylimV - H.VQ) / H.S);
ylabel(ax, 'Magnetic Flux Density B (mT)', 'FontSize', 12, 'FontWeight', 'bold');
ax.YAxis(2).Color = [0.15 0.15 0.15];
yyaxis(ax, 'left');

xlim(ax, [0 4]);
xticks(ax, 0:0.5:4);
xlabel(ax, 'Distance (cm)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, sprintf('DRV5055A2: Distance vs. V_{out} and B (%s)', ttl), 'FontSize', 13, 'FontWeight', 'bold');
lg = legend(ax, [hS; hM], 'Location', legLoc, 'FontSize', 10, 'Box', 'on');

% Characteristics box: linear range, first valid B, noise, repeatability
iLin = find(~E.linear, 1, 'last') + 1;
spread = max(E.V, [], 2) - min(E.V, [], 2);
spread(~E.linear) = NaN;
[spMax, iSp] = max(spread);
sig = median(E.SD(E.linear, :), 'all');
annotationText = sprintf(['\\bf%s Characteristics\\rm\n', ...
    'Linear range (V_L): %.1f - %.1f cm\n', ...
    'B at %.1f cm: %.1f mT\n', ...
    'Noise \\sigma (median): %.1f mV = %.2f mT\n', ...
    'Max sweep spread in V_L: %.0f mV at %.1f cm'], ...
    ttl, d(iLin), d(end), d(iLin), (Vm(iLin) - H.VQ) / H.S, sig, sig / H.S, spMax, d(iSp));
hAnn = annotation(fig, 'textbox', [0 0 0.1 0.1], 'String', annotationText, 'FitBoxToText', 'on', ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
    'FontSize', 9.5, 'Margin', 5);
% Pin the box inside the axes frame: bottom-right for North, under the legend for South
drawnow;
axPos  = ax.Position;
annPos = hAnn.Position;
pad    = 0.012;
if strcmp(legLoc, 'northwest')
    hAnn.Position = [axPos(1) + axPos(3) - annPos(3) - pad, axPos(2) + 1.5 * pad, annPos(3), annPos(4)];
else
    lgPos = lg.Position;
    hAnn.Position = [axPos(1) + axPos(3) - annPos(3) - pad, lgPos(2) - annPos(4) - pad, annPos(3), annPos(4)];
end

hold(ax, 'off');
drawnow;
exportgraphics(fig, [outBase '.png'], 'Resolution', 600);
savefig(fig, [outBase '.fig']);
fprintf('Saved %s.png\n', outBase);
end
