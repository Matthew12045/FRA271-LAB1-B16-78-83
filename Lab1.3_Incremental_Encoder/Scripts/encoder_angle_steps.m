%% ENCODER_ANGLE_STEPS Repeatability at target angles set on the protractor (X4).
%  Data/Encoder/Data1: AMT_X4_deg<angle>_<run>.mat (45 deg steps) and Bourns_X4_deg<angle>_<run>.mat
%  (15 deg steps, one detent), 3 runs per angle, each run started from 0 deg. The logged
%  'theta_deg X4' (Count2Deg of the WrapAround output) at the end of the run is the measured angle;
%  the AMT103-V counts down in this direction, so |theta| is used.
%  A run whose angle still changed by more than 0.5 deg in its last 0.5 s had not settled:
%  it is drawn hollow and left out of the error statistics. AMT_X4_deg0_2.mat was not recorded.
%  Writes Results/encoder_angle_steps.csv.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data', 'Encoder', 'Data1');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = encoder_report_style();
SETTLE_DEG = 0.5;

cfg = struct('name', {'AMT103-V', 'Bourns PEC11R'}, 'prefix', {'AMT', 'Bourns'}, 'step', {45, 15});
rows = table();
for e = 1:2
    for target = 0:cfg(e).step:360
        for r = 1:3
            f = fullfile(dataDir, sprintf('%s_X4_deg%d_%d.mat', cfg(e).prefix, target, r));
            if ~exist(f, 'file'), continue; end
            ds = load(f, 'data').data;
            [th, t] = load_encoder_signal(ds, 'theta_deg X4');
            p = load_encoder_signal(ds, 'pulses X4');
            th = abs(th);
            tail = t >= t(end) - 0.5;
            moved = max(th(tail)) - min(th(tail));
            rows = [rows; table(string(cfg(e).name), target, r, abs(p(end)), th(end), th(end) - target, ...
                moved, moved <= SETTLE_DEG, ...
                'VariableNames', {'Encoder', 'Target_deg', 'Run', 'Counts', 'Measured_deg', 'Error_deg', ...
                                  'MovedLast05s_deg', 'Settled'})]; %#ok<AGROW>
        end
    end
end
writetable(rows, fullfile(repDir, 'encoder_angle_steps.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'encoder_angle_steps.csv'));

%% Statistics (targets > 0, settled runs only)
stats = struct();
for e = 1:2
    R = rows(rows.Encoder == cfg(e).name & rows.Target_deg > 0 & rows.Settled, :);
    g = findgroups(R.Target_deg);
    sdPer = splitapply(@std, R.Error_deg, g);
    stats(e).n = height(R);
    stats(e).mae = mean(abs(R.Error_deg));
    stats(e).bias = mean(R.Error_deg);
    stats(e).rmse = sqrt(mean(R.Error_deg .^ 2));
    stats(e).maxAbs = max(abs(R.Error_deg));
    stats(e).sdMed = median(sdPer);
    stats(e).sdMax = max(sdPer);
    stats(e).unsettled = nnz(rows.Encoder == cfg(e).name & ~rows.Settled);
    fprintf(['%s: n = %d settled runs | MAE %.2f | bias %+.2f | RMSE %.2f | max |err| %.2f deg | ', ...
        'SD between runs median %.2f, max %.2f deg | unsettled %d\n'], cfg(e).name, stats(e).n, stats(e).mae, ...
        stats(e).bias, stats(e).rmse, stats(e).maxAbs, stats(e).sdMed, stats(e).sdMax, stats(e).unsettled);
end
% counts per degree from a straight-line fit (settled AMT runs) -> CPR
R = rows(rows.Encoder == "AMT103-V" & rows.Settled, :);
pf = polyfit(R.Target_deg, R.Counts, 1);
fprintf('AMT103-V fit: %.3f counts/deg -> %.0f counts per 360 deg (X4), PPR %.0f\n', pf(1), 360 * pf(1), 90 * pf(1));

%% Figure: error at every target angle
fig = U.figure('Angle steps', 430);
fig.Position(3) = 620;                       % narrow canvas: legible text at half a page wide
ax = axes(fig);
U.axes(ax);
yline(ax, 0, '-', 'Color', U.ink, 'LineWidth', 1.2, 'HandleVisibility', 'off');
h = gobjects(0);
for e = [2 1]
    c = U.mode(2 * e - 1, :);                         % AMT blue, Bourns purple
    m = U.marker{2 * e - 1};
    R = rows(rows.Encoder == cfg(e).name, :);
    jit = (R.Run - 2) * 1.6;                          % small side shift so the 3 runs do not overlap
    ok = R.Settled;
    h(end + 1) = scatter(ax, R.Target_deg(ok) + jit(ok), R.Error_deg(ok), 46, c, m, 'filled', ...
        'MarkerFaceAlpha', 0.75, 'MarkerEdgeColor', c * 0.75, ...
        'DisplayName', sprintf('%s (%d\\circ steps)', short_name(cfg(e).name), cfg(e).step)); %#ok<SAGROW>
    if any(~ok)
        h(end + 1) = scatter(ax, R.Target_deg(~ok) + jit(~ok), R.Error_deg(~ok), 46, c, m, ...
            'LineWidth', 1.4, 'DisplayName', 'Still turning (not used)'); %#ok<SAGROW>
    end
    if e == 1
        Rs = R(R.Settled, :);
        [g, tg] = findgroups(Rs.Target_deg);
        mu = splitapply(@mean, Rs.Error_deg, g);
        h(end + 1) = plot(ax, tg, mu, '--', 'Color', U.ink, 'LineWidth', 2.0, 'DisplayName', 'AMT103-V mean'); %#ok<SAGROW>
    end
end
xlim(ax, [-10 370]);
xticks(ax, 0:45:360);
ylim(ax, [-2.5 5.8]);
xlabel(ax, 'Target angle (deg)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'Measured - target (deg)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'Angle error at protractor targets (X4, 3 runs)', 'FontSize', 12, 'FontWeight', 'bold');
% legend below the plot; the error statistics are in the report text next to the figure
legend(ax, h([2:end 1]), 'Location', 'southoutside', 'NumColumns', 2, 'FontSize', 10.5, 'Box', 'off');   % AMT entries first
U.save(fig, fullfile(figDir, 'angle_steps'));

%% ---------------------------------------------------------------- helpers
function s = short_name(name)
s = strrep(name, 'Bourns ', '');
end
