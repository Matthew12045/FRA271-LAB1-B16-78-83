%% ENCODER_PHASE A/B phase relationship and the signal order in CW and CCW rotation.
%  Channel A was wired to A0 (PA0) and B to A1 (PA1); both are sampled by the 12-bit ADC at 1 kHz.
%    AMT103-V : Data/เพิ่มเติม/AMT_AB_Slow.mat  (turned one way, then back)
%    Bourns   : Data/เพิ่มเติม/Bourns_AB.mat    (clicked one way, then back)
%  Direction names follow each datasheet: AMT103-V "A leads B for CCW rotation (viewed from front)",
%  Bourns PEC11R quadrature table: A leads B for CW. For each direction the cleanest window
%  (no illegal jump, longest state dwell) is plotted as sampled (stairs), not interpolated.
%  Phase of the AMT103-V: for 50 % duty square waves the fraction of samples with A ~= B is phi/180.
%  Writes Results/encoder_phase_summary.csv.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data', 'เพิ่มเติม');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = encoder_report_style();

cfg = struct( ...
    'name',   {'AMT103-V', 'Bourns PEC11R'}, ...
    'file',   {'AMT_AB_Slow.mat', 'Bourns_AB.mat'}, ...
    'aLeads', {'CCW', 'CW'}, ...          % datasheet direction when A leads B
    'span',   {0.040, 0.150}, ...         % window length (s)
    'dwell',  {3, 3}, ...                 % shortest state allowed in the window (samples)
    'out',    {'phase_amt', 'phase_bourns'});

summary = table();
for e = 1:2
    ds = load(fullfile(dataDir, cfg(e).file), 'data').data;
    [a, t] = load_encoder_signal(ds, 'A0');
    b = load_encoder_signal(ds, 'A1');
    keep = t >= 0.15;                         % the first ADC sample reads 0 V on both channels
    a = a(keep);  b = b(keep);  t = t(keep);
    vA = a * 3.3 / 4095;
    vB = b * 3.3 / 4095;
    Q = decode_quadrature(a, b, 0.5 * max(a));

    % direction of every legal step: +1 = A leads B, -1 = B leads A
    moving = Q.step ~= 0 & ~isnan(Q.step);
    nAlead = nnz(Q.step == 1);
    nBlead = nnz(Q.step == -1);
    tA = median(t(Q.step == 1));
    tB = median(t(Q.step == -1));

    % phase from the share of samples with A ~= B while turning (AMT only: square waves)
    act = movmax(double(moving), [50 50]) > 0;
    pDiff = mean(Q.A(act) ~= Q.B(act));
    duty = [mean(Q.A(act)) mean(Q.B(act))];
    if e == 2
        pDiff = NaN;  duty = [NaN NaN];   % the Bourns rests in state 11 between clicks, so time shares are not phase
    end

    fig = U.figure(cfg(e).name, 460);
    fig.Position(3) = 620;                    % narrow canvas: legible text at half a page wide
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    dirs = [-1 1];                        % B leads first, then A leads
    if tA < tB, dirs = [1 -1]; end
    for d = 1:2
        ax = nexttile(tl);
        U.axes(ax);
        [i0, i1] = clean_window(Q, t, dirs(d), cfg(e).span, cfg(e).dwell);
        w = i0:i1;
        tw = (t(w) - t(i0)) * 1000;
        stairs(ax, tw, vA(w) + 4.3, '-', 'Color', U.chA, 'LineWidth', 1.8);
        stairs(ax, tw, vB(w), '-', 'Color', U.chB, 'LineWidth', 1.8);
        plot(ax, tw, vA(w) + 4.3, '.', 'Color', U.chA * 0.8, 'MarkerSize', 7);
        plot(ax, tw, vB(w), '.', 'Color', U.chB * 0.8, 'MarkerSize', 7);
        yline(ax, 3.85, '-', 'Color', [0.85 0.85 0.85], 'LineWidth', 1.0);
        yticks(ax, [0 3.3 4.3 7.6]);
        yticklabels(ax, {'B: 0 V', 'B: 3.3 V', 'A: 0 V', 'A: 3.3 V'});
        ylim(ax, [-0.4 8.2]);
        xlim(ax, [0 tw(end)]);
        if dirs(d) > 0
            lead = 'A leads B';
            rot = cfg(e).aLeads;
        else
            lead = 'B leads A';
            rot = other_dir(cfg(e).aLeads);
        end
        order = state_order(Q.state(w), Q.step(w));
        % the state order is the evidence for the direction, so it goes in the title instead of a note box;
        % phase and duty cycle are in the report text and the CSV
        title(ax, sprintf('(%c) %s: %s (%s)', 'a' + d - 1, rot, lead, order), 'FontSize', 12, 'FontWeight', 'bold');
        if d == 2
            xlabel(ax, 'Time (ms)', 'FontSize', 12, 'FontWeight', 'bold');
        end
        ylabel(ax, 'Signal (V)', 'FontSize', 12, 'FontWeight', 'bold');
        fprintf('%s %s: window %.3f-%.3f s, order %s\n', cfg(e).name, lead, t(i0), t(i1), order);
    end
    U.save(fig, fullfile(figDir, cfg(e).out));

    T = table(string(cfg(e).name), string(cfg(e).file), nAlead, nBlead, tA, tB, Q.nIllegal, ...
        pDiff, 180 * pDiff, duty(1), duty(2), median(vA(Q.A)), median(vB(Q.B)), ...
        'VariableNames', {'Encoder', 'File', 'Steps_A_leads', 'Steps_B_leads', 'MedianTime_A_leads_s', ...
                          'MedianTime_B_leads_s', 'IllegalJumps', 'Share_A_ne_B', 'Phase_deg', ...
                          'Duty_A', 'Duty_B', 'HighLevel_A_V', 'HighLevel_B_V'});
    summary = [summary; T]; %#ok<AGROW>
end
disp(summary);
writetable(summary, fullfile(repDir, 'encoder_phase_summary.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'encoder_phase_summary.csv'));

%% ---------------------------------------------------------------- helpers
function [i0, i1] = clean_window(Q, t, dirSign, span, minDwell)
% Window of length span (s) whose steps all have sign dirSign, with no illegal jump and
% no state shorter than minDwell samples; among those, the one with the most state changes
% (most cycles), ties broken by the longest shortest state. Starts 3 samples before an edge.
n = round(span / (t(2) - t(1)));
edges = find(Q.step == dirSign);
best = [-inf -inf];  i0 = edges(1);  i1 = i0 + n;
for k = 1:numel(edges)
    s = edges(k) - 3;
    f = s + n;
    if s < 1 || f > numel(t), continue; end
    st = Q.step(s:f);
    if any(isnan(st)) || any(st == -dirSign) || nnz(st) < 4, continue; end
    ch = find(st ~= 0);
    dw = min(diff(ch));
    if dw < minDwell, continue; end
    score = [numel(ch) dw];
    if score(1) > best(1) || (score(1) == best(1) && score(2) > best(2))
        best = score;  i0 = s;  i1 = f;
    end
end
end

function s = state_order(state, step)
% Text such as '11 \rightarrow 01 \rightarrow 00 \rightarrow 10' for the first four states of the window.
names = {'00', '10', '11', '01'};          % state 0..3 = (A,B)
seq = state(1);
idx = find(step(2:end) ~= 0) + 1;            % a change on the first sample happened before the window
for i = idx(:)'
    seq(end + 1) = state(i); %#ok<AGROW>
    if numel(seq) == 5, break; end
end
s = strjoin(names(seq + 1), ' \\rightarrow ');   % strjoin turns \\ into \
end

function d = other_dir(d)
if strcmp(d, 'CW'), d = 'CCW'; else, d = 'CW'; end
end
