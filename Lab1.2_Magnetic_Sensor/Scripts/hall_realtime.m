%% HALL_REALTIME Real-time output while the magnet is moved continuously toward the sensor.
%  Raw ADC counts (A0) on the left axis and the flux density B in mT on the right axis,
%  using the same conversion as the Simulink model:
%      V (mV) = A0 * 3300 / 4095,   B (mT) = (V - 1650) / 30
%  Raw 1 kHz samples are plotted without smoothing. One figure per shield condition.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data');
figDir  = fullfile(rootDir, 'Figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

VQ = 1650;  S = 30;  VL = [200 3100];
toB = @(a) (a * 3300 / 4095 - VQ) / S;
toA = @(v) v * 4095 / 3300;

cfg = {
    'nocap', 'Unshielded', 'realtime_unshielded'
    'cap',   'Shielded',   'realtime_shielded'
};
northC = [0.12 0.45 0.80];
southC = [0.85 0.22 0.18];

for k = 1:size(cfg, 1)
    [tn, an] = load_moving(fullfile(dataDir, sprintf('moving_north_%s.mat', cfg{k, 1})));
    [ts, as] = load_moving(fullfile(dataDir, sprintf('moving_south_%s.mat', cfg{k, 1})));

    fig = figure('Color', 'w', 'Position', [100 100 860 560], 'Name', ['Real-time ' cfg{k, 2}]);
    set(fig, 'DefaultTextInterpreter', 'tex', ...
             'DefaultAxesTickLabelInterpreter', 'tex', ...
             'DefaultLegendInterpreter', 'tex');
    ax = axes(fig);
    hold(ax, 'on');
    set(ax, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
    grid(ax, 'on');
    yyaxis(ax, 'left');

    tMax = ceil(max(tn(end), ts(end)));
    yl = [0 4200];
    patch(ax, [0 tMax tMax 0], [yl(1) yl(1) toA(VL(1)) toA(VL(1))], [0.90 0.90 0.90], 'EdgeColor', 'none', 'HandleVisibility', 'off');
    patch(ax, [0 tMax tMax 0], [toA(VL(2)) toA(VL(2)) yl(2) yl(2)], [0.90 0.90 0.90], 'EdgeColor', 'none', 'HandleVisibility', 'off');
    text(ax, 0.3 * tMax, mean([toA(VL(2)) yl(2)]), 'Outside V_L (saturation)', 'FontSize', 9.5, ...
        'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'middle');
    text(ax, 0.3 * tMax, mean([yl(1) toA(VL(1))]), 'Outside V_L (saturation)', 'FontSize', 9.5, ...
        'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'middle');
    plot(ax, [0 tMax], toA([VQ VQ]), ':', 'Color', [0.30 0.30 0.30], 'LineWidth', 1.2, 'HandleVisibility', 'off');

    hN = plot(ax, tn, an, '-', 'Color', northC, 'LineWidth', 1.1, 'DisplayName', 'North pole');
    hS = plot(ax, ts, as, '-', 'Color', southC, 'LineWidth', 1.1, 'DisplayName', 'South pole');

    ylim(ax, yl);
    yticks(ax, 0:500:4000);
    ylabel(ax, 'Raw Signal A0 (ADC counts)', 'FontSize', 12, 'FontWeight', 'bold');
    ax.YAxis(1).Color = [0.15 0.15 0.15];
    yyaxis(ax, 'right');
    ylim(ax, toB(yl));
    ylabel(ax, 'Magnetic Flux Density B (mT)', 'FontSize', 12, 'FontWeight', 'bold');
    ax.YAxis(2).Color = [0.15 0.15 0.15];
    yyaxis(ax, 'left');

    xlim(ax, [0 tMax]);
    xlabel(ax, 'Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax, sprintf('DRV5055A2: Real-Time Raw Signal and B (%s)', cfg{k, 2}), 'FontSize', 13, 'FontWeight', 'bold');
    legend(ax, [hN hS], 'Location', 'northwest', 'FontSize', 10, 'Box', 'on');

    % Noise while the magnet is still far away (0.5 - 5 s), and the clipped extremes
    sigA = mean([std(an(tn > 0.5 & tn < 5)), std(as(ts > 0.5 & ts < 5))]);
    annotationText = sprintf(['\\bfReal-Time Output, %s (1 kHz)\\rm\n', ...
        'V = A0 \\times 3300/4095 = %.3f mV per count\n', ...
        'B = (V - 1650) / 30 mV/mT  (Simulink, live)\n', ...
        'Noise \\sigma (0.5 - 5 s): %.1f counts = %.2f mT\n', ...
        'Clipped at %.1f mT (North), %.1f mT (South)'], ...
        cfg{k, 2}, 3300 / 4095, sigA, sigA * 3300 / 4095 / S, toB(median(an(an < toA(VL(1))))), ...
        toB(median(as(as > toA(VL(2))))));
    hAnn = annotation(fig, 'textbox', [0 0 0.1 0.1], 'String', annotationText, 'FitBoxToText', 'on', ...
        'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
        'FontSize', 9.5, 'Margin', 5);
    drawnow;
    axPos  = ax.Position;
    annPos = hAnn.Position;
    pad    = 0.012;
    % Bottom-left, just above the lower saturation band (the traces are still near VQ there)
    bandTop = axPos(2) + axPos(4) * (toA(VL(1)) - yl(1)) / diff(yl);
    hAnn.Position = [axPos(1) + pad, bandTop + pad, annPos(3), annPos(4)];

    hold(ax, 'off');
    drawnow;
    outBase = fullfile(figDir, cfg{k, 3});
    exportgraphics(fig, [outBase '.png'], 'Resolution', 600);
    savefig(fig, [outBase '.fig']);
    fprintf('Saved %s.png  (North %.1f s, South %.1f s)\n', outBase, tn(end), ts(end));
end

%% ---------------------------------------------------------------- helpers
function [t, a] = load_moving(fpath)
% Raw A0 samples of a continuous run; the first sample (t = 0, A0 = 0) is dropped.
L  = load(fpath);
el = L.data.getElement('A0');
a  = double(el.Values.Data(:));
t  = el.Values.Time(:);
a  = a(2:end);
t  = t(2:end);
end
