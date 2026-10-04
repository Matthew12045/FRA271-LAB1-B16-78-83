%% ENCODER_SPEED_QUALITY Effect of rotation speed on the A/B signals, polled by the ADC at 1 kHz.
%  Slow and fast runs of each encoder (A = A0, B = A1) from Data/เพิ่มเติม:
%    AMT_AB_Slow.mat, AMT_AB_Fast.mat, Bourns_AB_Slow.mat, Bourns_AB_Fast.mat
%  A software X4 decoder (decode_quadrature) counts every state change. When both channels
%  change between two polls the jump is illegal: one state and the direction are lost.
%  Polling at fs can follow at most fs states/s = fs*60/(4*PPR) RPM.
%  Also reported: share of samples between 10 % and 90 % of the high level (slow edges) and
%  pulses shorter than 2 ms (contact bounce). An illegal jump right after a stale sample (both
%  channels repeated exactly) comes from the serial link, not from the encoder.
%  The first 150 ms (start-up) are skipped. Figure: (a) slow and (b) fast window, illegal jumps marked.
%  Writes Results/encoder_speed_quality.csv.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data', 'เพิ่มเติม');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = encoder_report_style();
fs = 1000;

cfg = struct( ...
    'name',  {'AMT103-V', 'Bourns PEC11R'}, ...
    'ppr',   {2048, 24}, ...
    'files', {{'AMT_AB_Slow.mat', 'AMT_AB_Fast.mat'}, {'Bourns_AB_Slow.mat', 'Bourns_AB_Fast.mat'}}, ...
    'win',   {[3.000 9.000], [2.420 9.040]}, ...   % window start (s) in the slow and fast run
    'span',  {0.060, 0.260}, ...
    'out',   {'speed_amt', 'speed_bourns'});
label = {'Slow', 'Fast'};

summary = table();
for e = 1:2
    fig = U.figure(cfg(e).name, 470);
    fig.Position(3) = 620;                  % narrow canvas: legible text at half a page wide
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    for s = 1:2
        ds = load(fullfile(dataDir, cfg(e).files{s}), 'data').data;
        [a, t] = load_encoder_signal(ds, 'A0');
        b = load_encoder_signal(ds, 'A1');
        keep = t >= 0.15;                     % the first ADC sample reads 0 V on both channels
        a = a(keep);  b = b(keep);  t = t(keep);
        hiA = median(a(a > 0.5 * max(a)));
        hiB = median(b(b > 0.5 * max(b)));
        Q = decode_quadrature(a, b, 0.5 * max(a));

        % turning part of the run: within 0.25 s of a state change
        moving = movmax(double(Q.step ~= 0), [250 250]) > 0;
        T = nnz(moving) / fs;
        changes = Q.nLegal + Q.nIllegal;
        rate = (Q.nLegal + 2 * Q.nIllegal) / T;                 % states per second (lower bound)
        rate1s = movsum(double(Q.step ~= 0) + double(isnan(Q.step)), fs);
        slowA = mean(a(moving) > 0.1 * hiA & a(moving) < 0.9 * hiA);
        slowB = mean(b(moving) > 0.1 * hiB & b(moving) < 0.9 * hiB);
        glitch = short_pulses(Q.A, 2) + short_pulses(Q.B, 2);
        % a stale serial packet repeats both channels exactly; only detectable when a channel is not at 0
        stale = [false; a(2:end) == a(1:end-1) & b(2:end) == b(1:end-1) & max(a(2:end), b(2:end)) > 0.1 * hiA];
        ill = find(isnan(Q.step));
        afterStale = nnz(stale(max(ill - 1, 1)));

        R = table(string(cfg(e).name), string(label{s}), string(cfg(e).files{s}), T, changes, Q.nIllegal, ...
            100 * Q.nIllegal / changes, median(Q.dwell), 100 * mean(Q.dwell == 1), rate, max(rate1s), ...
            rate * 360 / (4 * cfg(e).ppr), max(rate1s) * 360 / (4 * cfg(e).ppr), 100 * slowA, 100 * slowB, glitch, ...
            afterStale, 100 * mean(stale), ...
            'VariableNames', {'Encoder', 'Speed', 'File', 'TurningTime_s', 'StateChanges', 'IllegalJumps', ...
                              'Illegal_pct', 'MedianDwell_ms', 'Dwell1ms_pct', 'StateRate_per_s', 'StateRateMax1s_per_s', ...
                              'Speed_deg_s', 'SpeedMax1s_deg_s', 'SlowEdgeA_pct', 'SlowEdgeB_pct', 'Pulses_le_2ms', ...
                              'Illegal_after_stale', 'StaleSamples_pct'});
        summary = [summary; R]; %#ok<AGROW>

        % plot window
        ax = nexttile(tl);
        U.axes(ax);
        w = t >= cfg(e).win(s) & t <= cfg(e).win(s) + cfg(e).span;
        tw = (t(w) - cfg(e).win(s)) * 1000;
        vA = a(w) * 3.3 / 4095;
        vB = b(w) * 3.3 / 4095;
        stairs(ax, tw, vA + 4.3, '-', 'Color', U.chA, 'LineWidth', 1.6);
        stairs(ax, tw, vB, '-', 'Color', U.chB, 'LineWidth', 1.6);
        plot(ax, tw, vA + 4.3, '.', 'Color', U.chA * 0.8, 'MarkerSize', 6);
        plot(ax, tw, vB, '.', 'Color', U.chB * 0.8, 'MarkerSize', 6);
        iw = find(isnan(Q.step) & w);
        hI = plot(ax, (t(iw) - cfg(e).win(s)) * 1000, 8.9 * ones(size(iw)), 'kv', ...
            'MarkerFaceColor', [0.2 0.2 0.2], 'MarkerSize', 6, 'DisplayName', 'Illegal jump (A and B changed between polls)');
        yline(ax, 3.85, '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 1.0);
        yticks(ax, [0 3.3 4.3 7.6]);
        yticklabels(ax, {'B: 0 V', 'B: 3.3 V', 'A: 0 V', 'A: 3.3 V'});
        ylim(ax, [-0.4 9.8]);
        xlim(ax, [0 cfg(e).span * 1000]);
        ylabel(ax, 'Signal (V)', 'FontSize', 12, 'FontWeight', 'bold');
        if s == 2
            xlabel(ax, 'Time (ms)', 'FontSize', 12, 'FontWeight', 'bold');
        end
        % short title with the key number; the other statistics are in the report text and the CSV
        title(ax, sprintf('(%c) %s rotation, %.1f%% illegal jumps', 'a' + s - 1, label{s}, 100 * Q.nIllegal / changes), ...
            'FontSize', 12, 'FontWeight', 'bold');
        if s == 2 && ~isempty(iw)
            legend(ax, hI, 'Location', 'southoutside', 'FontSize', 10.5, 'Box', 'off');
        end
    end
    U.save(fig, fullfile(figDir, cfg(e).out));
end
disp(summary);
writetable(summary, fullfile(repDir, 'encoder_speed_quality.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'encoder_speed_quality.csv'));
for e = 1:2
    fprintf('%s: polling limit %g states/s = %.1f deg/s = %.1f RPM\n', cfg(e).name, fs, ...
        fs * 360 / (4 * cfg(e).ppr), fs * 60 / (4 * cfg(e).ppr));
end

%% ---------------------------------------------------------------- helpers
function n = short_pulses(x, maxLen)
% Number of high or low pulses lasting maxLen samples or fewer (bounce / glitches).
ch = find(diff(x) ~= 0);
n = nnz(diff(ch) <= maxLen);
end
