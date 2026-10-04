%% ENCODER_WRAPAROUND 16-bit counter overflow/underflow and the WrapAround result.
%  Data/เพิ่มเติม/AMT_wraparound.mat     AMT103-V, X4, turned about 24 revolutions in one direction
%  Data/เพิ่มเติม/Bourns_wraparoundmat.mat Bourns, X4, turned back and forth across count 0
%  EncoderX4 is the raw timer value (0 .. 65535, TIM4 counter period 65536); pulses X4 is the
%  WrapAround output logged by the model. A wrap is a one-sample change larger than half the period.
%  The raw counts are fed again through WrapAroundModel.m (the code of the model block) and the
%  result is compared sample by sample with the logged pulses.
%  Writes Results/encoder_wraparound_summary.csv.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data', 'เพิ่มเติม');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = encoder_report_style();
MAXC = 65536;

cfg = struct('name', {'AMT103-V', 'Bourns PEC11R'}, ...
    'file', {'AMT_wraparound.mat', 'Bourns_wraparoundmat.mat'}, 'cpr', {8192, 96}, 'out', {'wrap_amt', 'wrap_bourns'});

summary = table();
for e = 1:2
    ds = load(fullfile(dataDir, cfg(e).file), 'data').data;
    [raw, t] = load_encoder_signal(ds, 'EncoderX4');
    pLog = load_encoder_signal(ds, 'pulses X4');

    clear WrapAroundModel
    pRe = zeros(size(raw));
    for i = 1:numel(raw)
        pRe(i) = WrapAroundModel(raw(i), 0);
    end
    d = diff(raw);
    under = find(d > MAXC / 2) + 1;          % 0 -> 65535 while counting down
    over  = find(d < -MAXC / 2) + 1;         % 65535 -> 0 while counting up
    under = under(t(under) >= 0.15);         % the start-up blank window is not motion
    over  = over(t(over) >= 0.15);
    i0 = find(t >= 0.15, 1);
    naive = raw - raw(i0);                    % what a plain difference without wrap handling gives
    net = numel(over) - numel(under);
    expect = raw(end) - raw(i0) + MAXC * net;

    T = table(string(cfg(e).name), raw(i0), raw(end), numel(under), numel(over), pLog(end), expect, ...
        max(abs(pRe - pLog)), min(pLog), max(pLog), pLog(end) / cfg(e).cpr, ...
        'VariableNames', {'Encoder', 'RawStart', 'RawEnd', 'Underflows', 'Overflows', 'PulsesEnd', ...
                          'Expected_from_raw', 'MaxDiff_offline_vs_logged', 'PulsesMin', 'PulsesMax', 'Turns'});
    summary = [summary; T]; %#ok<AGROW>

    fig = U.figure(cfg(e).name, 400);
    fig.Position(3) = 620;                    % narrow canvas: legible text at half a page wide
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl);
    U.axes(ax1);
    plot(ax1, t, raw, '-', 'Color', U.mode(1, :), 'LineWidth', 1.4);
    nameU = sprintf('Underflow 0 \\rightarrow 65535 (%d\\times)', numel(under));
    nameO = sprintf('Overflow 65535 \\rightarrow 0 (%d\\times)', numel(over));
    plot(ax1, t(under), raw(under), 'v', 'Color', U.ink, 'MarkerFaceColor', U.mode(2, :), 'MarkerSize', 7);
    plot(ax1, t(over), raw(over), '^', 'Color', U.ink, 'MarkerFaceColor', U.mode(3, :), 'MarkerSize', 7);
    ylim(ax1, [-4000 70000]);
    ax1.YAxis.Exponent = 0;
    yticks(ax1, [0 16384 32768 49152 65535]);
    yticklabels(ax1, {'0', '16384', '32768', '49152', '65535'});
    ylabel(ax1, 'EncoderX4 (raw)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax1, '(a) Raw 16-bit timer count (EncoderX4)', 'FontSize', 12, 'FontWeight', 'bold');

    ax2 = nexttile(tl);
    U.axes(ax2);
    hL = plot(ax2, t, pLog, '-', 'Color', U.mode(3, :), 'LineWidth', 2.4, 'DisplayName', 'pulses X4 (logged)');
    hR = plot(ax2, t, pRe, '--', 'Color', U.ink, 'LineWidth', 1.2, 'DisplayName', 'Recomputed offline');
    % stand-ins so the wrap markers of (a) share the legend below (b)
    dU = plot(ax2, NaN, NaN, 'v', 'Color', U.ink, 'MarkerFaceColor', U.mode(2, :), 'MarkerSize', 7, 'DisplayName', nameU);
    dO = plot(ax2, NaN, NaN, '^', 'Color', U.ink, 'MarkerFaceColor', U.mode(3, :), 'MarkerSize', 7, 'DisplayName', nameO);
    for k = [under(:); over(:)]'
        xline(ax2, t(k), ':', 'Color', U.grey, 'LineWidth', 1.0, 'HandleVisibility', 'off');
    end
    ylabel(ax2, 'Pulses', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax2, 'Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax2, '(b) Pulses after WrapAround', 'FontSize', 12, 'FontWeight', 'bold');
    pad = 0.08 * (max(pLog) - min(pLog));
    ylim(ax2, [min(pLog) - pad, max(pLog) + pad]);
    % one legend below the figure; the end-value check is in the report text and the CSV
    wrapH = [dU dO];
    wrapH = wrapH([~isempty(under) ~isempty(over)]);   % no entry for a wrap that never happened
    legend(ax2, [wrapH hL hR], 'Location', 'southoutside', 'NumColumns', 2, 'FontSize', 10.5, 'Box', 'off');
    linkaxes([ax1 ax2], 'x');
    xlim(ax2, [0 t(end)]);
    U.save(fig, fullfile(figDir, cfg(e).out));
    fprintf('%s: naive (no wrap handling) range %d .. %d\n', cfg(e).name, min(naive), max(naive));
end
disp(summary);
writetable(summary, fullfile(repDir, 'encoder_wraparound_summary.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'encoder_wraparound_summary.csv'));

%% Lab Sheet example: Counter Period 61439 (period M = 61440), same code with MAXC changed
code = fileread(fullfile(thisDir, 'WrapAroundModel.m'));
code = strrep(code, 'function pos_count = WrapAroundModel(', 'function pos_count = WrapAround61440(');
code = strrep(code, 'MAXC          = 65536;', 'MAXC          = 61440;');
tmpDir = fullfile(tempdir, 'encoder_wrap_test');
if ~exist(tmpDir, 'dir'), mkdir(tmpDir); end
fid = fopen(fullfile(tmpDir, 'WrapAround61440.m'), 'w');
fprintf(fid, '%s', code);
fclose(fid);
addpath(tmpDir);
clear WrapAround61440
seq = [61437 * ones(1, 150), 61438, 61439, 0, 1, 2, 1, 0, 61439, 61438];
pos = zeros(size(seq));
for i = 1:numel(seq)
    pos(i) = WrapAround61440(seq(i), 0);
end
rmpath(tmpDir);
fprintf('M = 61440 test, raw : %s\n', mat2str(seq(151:end)));
fprintf('                pos : %s\n', mat2str(pos(151:end)));
fprintf('             steps : %s\n', mat2str(diff(pos(150:end))));
