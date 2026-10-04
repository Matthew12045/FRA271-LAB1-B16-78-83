%% HALL_SHIELDING Effect of the steel shield plate on the flux density at the sensor.
%  Plots the sweep-mean B vs distance for North/South with and without the shield
%  and tabulates the reduction dB = |B_unshielded| - |B_shielded| and dB / |B_unshielded|.
%  dB uses the voltage difference only, so it does not depend on the assumed VQ.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end
outBase = fullfile(figDir, 'shielding_effect');

H = load_hall_sweeps(rootDir);
d = H.d;
Bsat = (H.VL(2) - H.VQ) / H.S;   % |B| at the edge of VL (48.3 mT)

northC = [0.12 0.45 0.80];
southC = [0.85 0.22 0.18];
series = {
    'North',    northC, '-',  'o', true,  'North, Unshielded'
    'North_Sh', northC, '--', 's', false, 'North, Shielded'
    'South',    southC, '-',  'o', true,  'South, Unshielded'
    'South_Sh', southC, '--', 's', false, 'South, Shielded'
};

fig = figure('Color', 'w', 'Position', [100 100 860 560], 'Name', 'Shielding effect');
set(fig, 'DefaultTextInterpreter', 'tex', ...
         'DefaultAxesTickLabelInterpreter', 'tex', ...
         'DefaultLegendInterpreter', 'tex');
ax = axes(fig);
hold(ax, 'on');
set(ax, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
grid(ax, 'on');

yl = [-60 60];
patch(ax, [0 4 4 0], [Bsat Bsat yl(2) yl(2)], [0.90 0.90 0.90], 'EdgeColor', 'none', 'HandleVisibility', 'off');
patch(ax, [0 4 4 0], [yl(1) yl(1) -Bsat -Bsat], [0.90 0.90 0.90], 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(ax, 1.0, mean([Bsat yl(2)]), 'Outside V_L (saturation)', 'FontSize', 9.5, 'Color', [0.35 0.35 0.35], ...
    'VerticalAlignment', 'middle');
text(ax, 1.0, mean([yl(1) -Bsat]), 'Outside V_L (saturation)', 'FontSize', 9.5, 'Color', [0.35 0.35 0.35], ...
    'VerticalAlignment', 'middle');
yline(ax, 0, '-', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.8, 'HandleVisibility', 'off');

h = gobjects(size(series, 1), 1);
for k = 1:size(series, 1)
    E  = H.(series{k, 1});
    c  = series{k, 2};
    Bm = mean(E.B, 2);
    Bs = std(E.B, 0, 2);
    if series{k, 5}
        face = c;
    else
        face = 'w';
    end
    errorbar(ax, d, Bm, Bs, 'LineStyle', 'none', 'LineWidth', 0.8, 'CapSize', 3, ...
        'Color', c * 0.5 + 0.5, 'HandleVisibility', 'off');
    h(k) = plot(ax, d, Bm, [series{k, 3}, series{k, 4}], 'Color', c, 'LineWidth', 1.6, ...
        'MarkerSize', 6, 'MarkerFaceColor', face, 'MarkerEdgeColor', c * 0.8, ...
        'DisplayName', series{k, 6});
end

xlim(ax, [0 4]);
xticks(ax, 0:0.5:4);
ylim(ax, yl);
yticks(ax, -60:10:60);
xlabel(ax, 'Distance (cm)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'Magnetic Flux Density B (mT)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'DRV5055A2: Shielded vs. Unshielded Magnetic Flux Density', 'FontSize', 13, 'FontWeight', 'bold');
lg = legend(ax, h, 'Location', 'northeast', 'FontSize', 10, 'Box', 'on');

%% Shielding table (sweep means)
% dB = |B_unshielded| - |B_shielded| (positive = the shield reduces B at the sensor)
dB_N = (mean(H.North_Sh.V, 2) - mean(H.North.V, 2)) / H.S;   % North: |B| = (VQ - V) / S
dB_S = (mean(H.South.V, 2) - mean(H.South_Sh.V, 2)) / H.S;   % South: |B| = (V - VQ) / S
Bu_N = mean(H.North.B, 2);  Bu_S = mean(H.South.B, 2);
red_N = 100 * dB_N ./ abs(Bu_N);
red_S = 100 * dB_S ./ abs(Bu_S);
both = H.North.linear & H.North_Sh.linear & H.South.linear & H.South_Sh.linear;
T = table(d, Bu_N, mean(H.North_Sh.B, 2), dB_N, red_N, Bu_S, mean(H.South_Sh.B, 2), dB_S, red_S, both, ...
    'VariableNames', {'Distance_cm', 'B_North_mT', 'B_North_Sh_mT', 'dB_North_mT', 'Reduction_North_pct', ...
                      'B_South_mT', 'B_South_Sh_mT', 'dB_South_mT', 'Reduction_South_pct', 'AllInsideVL'});
writetable(T, fullfile(repDir, 'hall_shielding_summary.csv'));
disp(T);

tol  = 1e-9;                     % distances come from 0.1:0.2:3.7 (not exact binary values)
near = both & d <= 1.5 + tol;
far  = d >= 2.5 - tol;
i09  = abs(d - 0.9) < tol;
iN = find(~H.North.linear, 1, 'last'); iNs = find(~H.North_Sh.linear, 1, 'last');
annotationText = sprintf(['\\bfShielding Effect (sweep means)\\rm\n', ...
    'Reduction at 0.9 - 1.5 cm: %.0f - %.0f %%\n', ...
    'Max |\\DeltaB|: %.1f mT (N), %.1f mT (S) at 0.9 cm\n', ...
    '|\\DeltaB| at 2.5 - 3.7 cm: \\leq %.1f mT\n', ...
    'Last saturated point (North): %.1f \\rightarrow %.1f cm'], ...
    min([red_N(near); red_S(near)]), max([red_N(near); red_S(near)]), ...
    dB_N(i09), dB_S(i09), max(abs([dB_N(far); dB_S(far)])), d(iN), d(iNs));
hAnn = annotation(fig, 'textbox', [0 0 0.1 0.1], 'String', annotationText, 'FitBoxToText', 'on', ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
    'FontSize', 9.5, 'Margin', 5);
drawnow;
axPos  = ax.Position;
annPos = hAnn.Position;
pad    = 0.012;
% Bottom-right corner, above the lower saturation band
bandTop = axPos(2) + axPos(4) * (-Bsat - yl(1)) / diff(yl);
hAnn.Position = [axPos(1) + axPos(3) - annPos(3) - pad, bandTop + pad, annPos(3), annPos(4)];

hold(ax, 'off');
drawnow;
exportgraphics(fig, [outBase '.png'], 'Resolution', 600);
savefig(fig, [outBase '.fig']);
fprintf('Saved %s.png\n', outBase);
