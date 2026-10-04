%% LC_CALIBRATION Calibration of the YZC-131A + INA125 load cell from the three loading runs.
%  1) Steady-state voltage of the 33 recordings in Data/ (0 - 9.84 kg, 3 runs, masses from
%     the digital scale) -> least-squares line V = S*m + V0 over all points.
%  2) Inverse (calibration) equation used in the Simulink model:
%        m = (V - V0) / S   [kg],   F = m * g   [N],   g = 9.81 m/s^2
%  3) Error of every point against the digital scale, m_pred - m_scale, for linearity
%     (max |error| as % of the 10 kg rated capacity) and repeatability (spread of the three
%     runs at the same load step).
%  Writes Results/lc_points.csv, Results/lc_runs.csv and Results/lc_calibration.mat.
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
U = lc_report_style();

G_ACC = 9.81;      % m/s^2
CAP   = 10;        % kg, rated capacity of the YZC-131A
GAIN  = 4 + 60e3 / 127;   % INA125 with RG = 127 ohm

%% 1. Steady-state points and the pooled fit
T = load_lc_runs(dataDir);
m = T.Mass_kg;  V = T.V_mean;
p = polyfit(m, V, 1);
S = p(1);  V0 = p(2);
Vfit = polyval(p, m);
R2 = 1 - sum((V - Vfit).^2) / sum((V - mean(V)).^2);
T.Mass_pred_kg = (V - V0) / S;
T.Err_kg = T.Mass_pred_kg - m;
T.Err_pctFS = 100 * T.Err_kg / CAP;
T.Force_N = T.Mass_pred_kg * G_ACC;
T.Step = zeros(height(T), 1);
for r = unique(T.Run)'
    T.Step(T.Run == r) = (0:nnz(T.Run == r) - 1)';
end
nonlin = max(abs(T.Err_kg));
rmse = sqrt(mean(T.Err_kg.^2));
noiseV = mean(T.V_std);

% Repeatability: spread of the three runs' errors at the same load step
steps = unique(T.Step);
spread = nan(numel(steps), 1);
for i = 1:numel(steps)
    e = T.Err_kg(T.Step == steps(i));
    spread(i) = max(e) - min(e);
end
[repMax, iRep] = max(spread);

% Per-run fits
runs = unique(T.Run);
R = table();
for r = runs'
    k = T.Run == r;
    pr = polyfit(m(k), V(k), 1);
    vr = polyval(pr, m(k));
    R = [R; table(r, pr(1) * 1000, pr(2), 1 - sum((V(k) - vr).^2) / sum((V(k) - mean(V(k))).^2), ...
        max(abs(T.Err_kg(k))), sqrt(mean(T.Err_kg(k).^2)), ...
        'VariableNames', {'Run', 'S_mV_per_kg', 'V0_V', 'R2', 'MaxErr_kg', 'RMSE_kg'})]; %#ok<AGROW>
end

fprintf('Pooled fit (%d points): V = %.5f m + %.5f  (S = %.2f mV/kg, R^2 = %.6f)\n', numel(m), S, V0, S * 1000, R2);
fprintf('Inverse: m = (V - %.4f) / %.5f = %.4f V - %.4f kg ; F = %.3f V - %.3f N\n', V0, S, 1 / S, V0 / S, G_ACC / S, G_ACC * V0 / S);
fprintf('Input-referred: S/G = %.4f mV/kg, V0/G = %.3f mV (G = %.1f) -> %.3f mV/V at 5 V excitation\n', ...
    S / GAIN * 1000, V0 / GAIN * 1000, GAIN, S / GAIN * 1000 * CAP / 5);
fprintf('Non-linearity max |err| = %.1f g (%.2f %%FS), RMSE = %.1f g\n', nonlin * 1000, 100 * nonlin / CAP, rmse * 1000);
fprintf('Repeatability: max spread %.1f g (%.2f %%FS) at step %d; mean spread %.1f g\n', repMax * 1000, ...
    100 * repMax / CAP, steps(iRep), mean(spread) * 1000);
fprintf('Noise (sample SD, mean of files) = %.2f mV = %.1f counts = %.1f g\n', noiseV * 1000, noiseV / 3.3 * 4095, noiseV / S * 1000);
fprintf('ADC resolution: %.3f mV/count = %.2f g/count = %.4f N/count\n', 3300 / 4095, 3.3 / 4095 / S * 1000, 3.3 / 4095 / S * G_ACC);
disp(R);

writetable(T, fullfile(repDir, 'lc_points.csv'));
writetable(R, fullfile(repDir, 'lc_runs.csv'));
cal = struct('S', S, 'V0', V0, 'R2', R2, 'g', G_ACC, 'gain', GAIN, 'nonlin_kg', nonlin, 'rmse_kg', rmse, ...
    'rep_kg', repMax, 'noise_V', noiseV);
save(fullfile(repDir, 'lc_calibration.mat'), 'cal', 'T', 'R');

%% 2. Figure: calibration line
fig = U.figure('Calibration');
ax = axes(fig);
U.axes(ax);
mm = [-0.3 10.3];
hFit = plot(ax, mm, polyval(p, mm), '--', 'Color', U.ink, 'LineWidth', 2.0, 'DisplayName', sprintf('Fit: V = %.4f m + %.4f V,  R^2 = %.5f', S, V0, R2));
h = gobjects(numel(runs), 1);
for i = 1:numel(runs)
    k = T.Run == runs(i);
    c = U.run(i, :);
    plot(ax, m(k), V(k), '-', 'Color', U.pale(c, 0.55), 'LineWidth', 1.2, 'HandleVisibility', 'off');
    h(i) = plot(ax, m(k), V(k), U.marker{i}, 'Color', c * 0.8, 'MarkerFaceColor', c, 'MarkerSize', 7, ...
        'DisplayName', sprintf('Run %d', runs(i)));
end
xlim(ax, mm);
ylim(ax, [0 3.5]);
yline(ax, 3.3, ':', 'ADC full scale 3.3 V', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.2, ...
    'LabelHorizontalAlignment', 'right', 'FontSize', 9.5, 'HandleVisibility', 'off');
xlabel(ax, 'Mass on the Digital Scale m (kg)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'INA125 Output Voltage V (V)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'YZC-131A + INA125 (G = 476): Output Voltage vs Mass, 3 Runs', 'FontSize', 13, 'FontWeight', 'bold');
legend(ax, [h; hFit], 'Location', 'northwest', 'FontSize', 10, 'Box', 'on');
U.save(fig, fullfile(figDir, 'lc_calibration'));

%% 3. Figure: error against the digital scale (linearity and repeatability)
fig = U.figure('Error vs scale', 520);
ax = axes(fig);
U.axes(ax);
yline(ax, 0, '-', 'Color', U.grey, 'LineWidth', 1.0, 'HandleVisibility', 'off');
for i = 1:numel(runs)
    k = T.Run == runs(i);
    c = U.run(i, :);
    plot(ax, m(k), 1000 * T.Err_kg(k), '-', 'Color', U.pale(c, 0.55), 'LineWidth', 1.2, 'HandleVisibility', 'off');
    h(i) = plot(ax, m(k), 1000 * T.Err_kg(k), U.marker{i}, 'Color', c * 0.8, 'MarkerFaceColor', c, 'MarkerSize', 7, ...
        'DisplayName', sprintf('Run %d', runs(i)));
end
ylim(ax, [-110 110]);
xlim(ax, mm);
xlabel(ax, 'Mass on the Digital Scale m (kg)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'Error m_{pred} - m_{scale} (g)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'Load Cell Reading vs Digital Scale (Calibration Runs)', 'FontSize', 13, 'FontWeight', 'bold');
legend(ax, h, 'Location', 'northwest', 'FontSize', 10, 'Box', 'on', 'Orientation', 'horizontal');
U.save(fig, fullfile(figDir, 'lc_error_scale'));
