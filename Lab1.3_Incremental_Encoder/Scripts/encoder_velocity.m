%% ENCODER_VELOCITY Raw counts -> relative position (pulses) -> angle (rad) -> angular velocity (rad/s).
%  Data/เพิ่มเติม/AMT_Omega.mat and Bourns_Omega.mat (X4 path, logged by the Simulink model):
%    pulses X4        WrapAround output (relative position in counts)
%    theta_rad X4     Count2Rad: theta = 2*pi * pulses / (PPR * 4)
%    omega_final_X4   FilteredAngularVelocity: 1st-order low-pass on theta (fc_theta), backward
%                     difference / Ts, light low-pass on omega (fc_omega), Ts = 1 ms
%  Figure: (a) theta with pulses on the right-hand scale, (b) omega.
%  Grey: the plain 1 ms backward difference, where one count is 2*pi/(CPR*Ts) rad/s.
%  Dashed: slope of theta over a centred 0.2 s window (reference, not causal).
%  Jumps of 10 counts or more in one sample are counted (summary CSV) with their spacing: on the AMT103-V they
%  repeat about every 0.16 s, i.e. the serial link delivers late samples, not the encoder.
%  The logged omega is recomputed offline from theta_rad with FilteredAngularVelocity.m to confirm
%  the filter settings. Writes Results/encoder_velocity_summary.csv.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data', 'เพิ่มเติม');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = encoder_report_style();
Ts = 1e-3;

cfg = struct( ...
    'name', {'AMT103-V', 'Bourns PEC11R'}, 'file', {'AMT_Omega.mat', 'Bourns_Omega.mat'}, ...
    'ppr', {2048, 24}, 'fc', {[20 40], [2 5]}, 'out', {'velocity_amt', 'velocity_bourns'});

summary = table();
for e = 1:2
    ds = load(fullfile(dataDir, cfg(e).file), 'data').data;
    [p, t] = load_encoder_signal(ds, 'pulses X4');
    th = load_encoder_signal(ds, 'theta_rad X4');
    om = load_encoder_signal(ds, 'omega_final_X4');
    cpr = 4 * cfg(e).ppr;

    % checks: Count2Rad and the filter, recomputed offline
    errRad = max(abs(th - 2 * pi * p / cpr));
    clear FilteredAngularVelocity
    omRe = zeros(size(th));
    for i = 1:numel(th)
        omRe(i) = FilteredAngularVelocity(th(i), 0, Ts, cfg(e).fc(1), cfg(e).fc(2), true, false, 2 * pi);
    end
    errOm = max(abs(omRe - om));

    raw1 = [0; diff(th)] / Ts;                       % plain 1 ms backward difference
    nW = round(0.1 / Ts);
    ref = (th([nW + 1:end, end * ones(1, nW)]) - th([ones(1, nW), 1:end - nW])) ./ ...
          (t([nW + 1:end, end * ones(1, nW)]) - t([ones(1, nW), 1:end - nW]));
    jumps = find(abs(diff(p)) >= 10);
    gap = median(diff(t(jumps)));
    delay = 1 / (2 * pi * cfg(e).fc(1)) + 1 / (2 * pi * cfg(e).fc(2));   % low-frequency delay of the two filters

    T = table(string(cfg(e).name), p(end), th(end), th(end) / (2 * pi), max(abs(om)), max(abs(raw1)), ...
        2 * pi / cpr, 2 * pi / (cpr * Ts), errRad, errOm, delay, numel(jumps), max(abs(diff(p))), gap, ...
        'VariableNames', {'Encoder', 'FinalPulses', 'FinalTheta_rad', 'FinalTurns', 'PeakOmegaFinal_rad_s', ...
                          'PeakRawDiff_rad_s', 'Rad_per_count', 'RawDiffStep_rad_s', 'MaxErr_Count2Rad', ...
                          'MaxErr_Filter', 'FilterDelay_s', 'Jumps_ge10', 'MaxJump_counts', 'JumpSpacing_s'});
    summary = [summary; T]; %#ok<AGROW>

    % two panels only (position and velocity), on a narrow canvas so the text stays legible when the
    % figure is printed half a page wide; pulses are the right-hand scale of the same theta line
    fig = U.figure(cfg(e).name, 400);
    fig.Position(3) = 620;
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl);
    U.axes(ax1);
    stairs(ax1, t, th, '-', 'Color', U.mode(2, :), 'LineWidth', 1.8);
    thLim = [min(th) max(th)] + [-0.08 0.08] * max(max(th) - min(th), 1);
    ylim(ax1, thLim);
    ylabel(ax1, '\theta (rad)', 'FontSize', 12, 'FontWeight', 'bold');
    yyaxis(ax1, 'right');
    ylim(ax1, thLim * cpr / (2 * pi));                % same line read in pulses (WrapAround output)
    ylabel(ax1, 'Pulses', 'FontSize', 12, 'FontWeight', 'bold');
    ax1.YAxis(1).Color = U.ink;
    ax1.YAxis(2).Color = U.ink;
    yyaxis(ax1, 'left');
    title(ax1, sprintf('(a) Position: \\theta = 2\\pi \\times pulses / %d', cpr), 'FontSize', 12, 'FontWeight', 'bold');
    ax2 = nexttile(tl);
    U.axes(ax2);
    hR = plot(ax2, t, raw1, '-', 'Color', U.pale(U.grey, 0.3), 'LineWidth', 0.8, 'DisplayName', '1 ms difference');
    hF = plot(ax2, t, om, '-', 'Color', U.mode(3, :), 'LineWidth', 1.8, 'DisplayName', 'Filtered \omega');
    hS = plot(ax2, t, ref, '--', 'Color', U.ink, 'LineWidth', 1.4, 'DisplayName', '0.2 s slope of \theta');
    lim = 1.15 * max(abs([om; ref]));
    ylim(ax2, [-lim lim]);                            % the 1 ms difference is clipped at this range
    ylabel(ax2, '\omega (rad/s)', 'FontSize', 12, 'FontWeight', 'bold');
    xlabel(ax2, 'Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax2, '(b) Angular velocity', 'FontSize', 12, 'FontWeight', 'bold');
    legend(ax2, [hR hF hS], 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10.5, 'Box', 'off');
    linkaxes([ax1 ax2], 'x');
    xlim(ax2, [0 t(end)]);
    U.save(fig, fullfile(figDir, cfg(e).out));
end
disp(summary);
writetable(summary, fullfile(repDir, 'encoder_velocity_summary.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'encoder_velocity_summary.csv'));
