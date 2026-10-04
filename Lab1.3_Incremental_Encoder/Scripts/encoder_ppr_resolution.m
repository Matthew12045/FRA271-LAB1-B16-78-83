%% ENCODER_PPR_RESOLUTION Counts per revolution, PPR and angular resolution in X1/X2/X4.
%  1) The 60 one-revolution runs in Data/ (AMT103-V and Bourns PEC11R, X1/X2/X4, 10 runs each)
%     are unwrapped with the same WrapAround code as the Simulink model (16-bit counter,
%     first 150 samples blanked); the final count is the counts per revolution.
%     PPR = counts / k (k = 1, 2, 4) and resolution = 360 / (PPR * k).
%  2) X1/X2/X4 counting shown on real A/B samples: one Bourns detent from
%     Data/เพิ่มเติม/Bourns_AB_Slow.mat (A = A0, B = A1, polled at 1 kHz).
%  Writes Results/encoder_ppr_summary.csv (Table 1 of the report).
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end
U = encoder_report_style();

enc = struct('name', {'AMT103-V', 'Bourns PEC11R'}, 'prefix', {'AMT', 'bourns'}, 'ppr', {2048, 24});
k = [1 2 4];
nRun = 10;

%% 1. Counts per revolution
counts = nan(nRun, 3, 2);
for e = 1:2
    for m = 1:3
        for r = 1:nRun
            f = fullfile(dataDir, sprintf('%s_X%d_%d.mat', enc(e).prefix, k(m), r));
            raw = load_encoder_signal(f, sprintf('EncoderX%d', k(m)));
            counts(r, m, e) = unwrap_counts(raw);
        end
    end
end

summary = table();
for e = 1:2
    for m = 1:3
        c = counts(:, m, e);
        pprMeas = mean(c) / k(m);
        cpr = enc(e).ppr * k(m);
        T = table(string(enc(e).name), sprintf("X%d", k(m)), numel(c), mean(c), std(c), min(c), max(c), ...
            pprMeas, std(c) / k(m), cpr, 360 / cpr, 2 * pi / cpr, ...
            'VariableNames', {'Encoder', 'Mode', 'Runs', 'CountsMean', 'CountsStd', 'CountsMin', 'CountsMax', ...
                              'PPR_measured', 'PPR_std', 'CPR_datasheet', 'Res_deg_per_count', 'Res_rad_per_count'});
        summary = [summary; T]; %#ok<AGROW>
    end
end
disp(summary);
writetable(summary, fullfile(repDir, 'encoder_ppr_summary.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'encoder_ppr_summary.csv'));

%% 2. Figure: AMT103-V PPR estimate of every run
fig = U.figure('AMT PPR', 400);
fig.Position(3) = 620;                       % narrow canvas: legible text at half a page wide
ax = axes(fig);
U.axes(ax);
h = gobjects(3, 1);
for m = 1:3
    c = U.mode(m, :);
    y = counts(:, m, 1) / k(m);
    plot(ax, 1:nRun, y, '-', 'Color', U.pale(c, 0.55), 'LineWidth', 1.4, 'HandleVisibility', 'off');
    h(m) = plot(ax, 1:nRun, y, U.marker{m}, 'Color', c * 0.8, 'MarkerFaceColor', c, 'MarkerSize', 7, ...
        'DisplayName', sprintf('X%d', k(m)));
end
hN = yline(ax, enc(1).ppr, '--', 'Color', U.ink, 'LineWidth', 2.0, 'DisplayName', 'Datasheet 2,048');
xlim(ax, [0.5 nRun + 0.5]);
xticks(ax, 1:nRun);
ylim(ax, [2020 2100]);
xlabel(ax, 'Run', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'PPR = counts per rev / k', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'AMT103-V PPR from one turn (10 runs per mode)', 'FontSize', 12, 'FontWeight', 'bold');
% legend below the plot; the means and SDs are in Table 1 of the report and the CSV
legend(ax, [h; hN], 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10.5, 'Box', 'off');
U.save(fig, fullfile(figDir, 'ppr_amt'));

%% 3. Figure: X1/X2/X4 counting on one Bourns detent (polled A/B)
[a, t] = load_encoder_signal(fullfile(dataDir, 'เพิ่มเติม', 'Bourns_AB_Slow.mat'), 'A0');
b = load_encoder_signal(fullfile(dataDir, 'เพิ่มเติม', 'Bourns_AB_Slow.mat'), 'A1');
win = t >= 2.40 & t <= 2.86;      % two detent clicks, turning in the A-leads direction
Q = decode_quadrature(a(win), b(win), 2048);
tw = (t(win) - t(find(win, 1))) * 1000;
step = Q.step;
step(isnan(step)) = 0;                       % an illegal jump carries no direction
aEdge = [0; diff(Q.A)];
bEdge = [0; diff(Q.B)];
x4 = cumsum(step);                           % every A and B edge
x2 = cumsum(double(aEdge ~= 0) .* step);     % both edges of A only
x1 = cumsum(double(aEdge > 0) .* step);      % rising edges of A only

fig = U.figure('X1 X2 X4 counting', 460);
fig.Position(3) = 620;
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax1 = nexttile(tl);
U.axes(ax1);
stairs(ax1, tw, 1.4 + Q.A, '-', 'Color', U.chA, 'LineWidth', 1.8);
stairs(ax1, tw, double(Q.B), '-', 'Color', U.chB, 'LineWidth', 1.8);
iA = find(aEdge ~= 0);  iB = find(bEdge ~= 0);
edge_markers(ax1, tw(iA), 1.9, aEdge(iA), U.chA);
edge_markers(ax1, tw(iB), 0.5, bEdge(iB), U.chB);
yticks(ax1, [0 1 1.4 2.4]);
yticklabels(ax1, {'B = 0', 'B = 1', 'A = 0', 'A = 1'});
ylim(ax1, [-0.3 2.75]);
xlim(ax1, [0 tw(end)]);
title(ax1, '(a) PEC11R A/B over two detents, edges marked', 'FontSize', 12, 'FontWeight', 'bold');
ax2 = nexttile(tl);
U.axes(ax2);
hc = gobjects(3, 1);
cnt = {x1, x2, x4};
lw = [1.6 2.8 4.0];                          % nested widths keep shared segments visible
for m = 3:-1:1
    hc(m) = stairs(ax2, tw, cnt{m}, '-', 'Color', U.pale(U.mode(m, :), 0.15 * (m - 1)), 'LineWidth', lw(m), ...
        'DisplayName', sprintf('X%d: %d per detent', k(m), k(m)));
    iEnd = find(diff(cnt{m}) ~= 0) + 1;
    plot(ax2, tw(iEnd), cnt{m}(iEnd), U.marker{m}, 'Color', U.mode(m, :) * 0.8, ...
        'MarkerFaceColor', U.mode(m, :), 'MarkerSize', 6, 'HandleVisibility', 'off');
end
xlim(ax2, [0 tw(end)]);
ylim(ax2, [-0.5 8.8]);
xlabel(ax2, 'Time (ms)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax2, 'Count', 'FontSize', 12, 'FontWeight', 'bold');
title(ax2, '(b) Counts from the same edges', 'FontSize', 12, 'FontWeight', 'bold');
legend(ax2, hc, 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10.5, 'Box', 'off');
U.save(fig, fullfile(figDir, 'x1x2x4_bourns'));
fprintf('Bourns counts per revolution: X1 %s | X2 %s | X4 %s\n', mat2str(unique(counts(:, 1, 2))'), ...
    mat2str(unique(counts(:, 2, 2))'), mat2str(unique(counts(:, 3, 2))'));

%% ---------------------------------------------------------------- helpers
function edge_markers(ax, t, y, dir, c)
% Up triangle on a rising edge, down triangle on a falling edge.
plot(ax, t(dir > 0), y * ones(nnz(dir > 0), 1), '^', 'Color', c * 0.8, 'MarkerFaceColor', c, 'MarkerSize', 6);
plot(ax, t(dir < 0), y * ones(nnz(dir < 0), 1), 'v', 'Color', c * 0.8, 'MarkerFaceColor', c, 'MarkerSize', 6);
end

function n = unwrap_counts(raw)
% Final count of one run through the model's WrapAround code (reset = 0).
clear WrapAroundModel
pos = zeros(size(raw));
for i = 1:numel(raw)
    pos(i) = WrapAroundModel(raw(i), 0);
end
n = pos(end);
end
