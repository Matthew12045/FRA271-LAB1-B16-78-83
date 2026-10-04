%% LC_VALIDATION Compare the calibrated load cell with the digital scale on the validation run (run 4).
%  Run 4 (Data/Validation, logged one day after runs 1-3) is not used in the calibration. Each file
%  is reduced with load_lc_runs (steady mean of A0, t >= 0.5 s) and converted with the calibration of
%  lc_calibration.m:  m = (V - V0) / S,  F = m * g.
%  Reported: error m_load cell - m_scale (g), % of reading, % of the 10 kg capacity, RMSE, and the
%  linearity of run 4 itself (R^2 and max deviation from its own line); the run 4 line is also
%  compared with the calibration line (zero and sensitivity).
%  Writes Results/lc_validation.csv (Table of the report).
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = lc_report_style();
L = load(fullfile(repDir, 'lc_calibration.mat'));
cal = L.cal;  Tc = L.T;
CAP = 10;

%% 1. Validation points
T = load_lc_runs(fullfile(rootDir, 'Data', 'Validation'));
m = T.Mass_kg;  V = T.V_mean;
T.Mass_pred_kg = (V - cal.V0) / cal.S;
T.Force_N = T.Mass_pred_kg * cal.g;
T.Err_g = 1000 * (T.Mass_pred_kg - m);
T.Err_pct_reading = 100 * (T.Mass_pred_kg - m) ./ m;
T.Err_pct_reading(m == 0) = NaN;
T.Err_pctFS = 100 * (T.Mass_pred_kg - m) / CAP;

p4 = polyfit(m, V, 1);
v4 = polyval(p4, m);
R2_4 = 1 - sum((V - v4).^2) / sum((V - mean(V)).^2);
lin4 = max(abs(V - v4)) / p4(1);                    % kg, deviation from run 4's own line
pe = polyfit(m, T.Err_g, 1);                        % error trend, g per kg

fprintf('Validation (run 4, %d points)\n', height(T));
disp(T(:, {'File', 'Mass_kg', 'V_mean', 'Mass_pred_kg', 'Force_N', 'Err_g', 'Err_pct_reading', 'Err_pctFS'}));
fprintf('Max abs error %.0f g (%.2f %%FS), RMSE %.0f g, mean %% of reading (m > 0) %.2f %%\n', ...
    max(abs(T.Err_g)), max(abs(T.Err_pctFS)), sqrt(mean(T.Err_g.^2)), mean(T.Err_pct_reading, 'omitnan'));
fprintf('Run 4 line: V = %.5f m + %.5f (S = %.2f mV/kg, R^2 = %.6f), max deviation %.1f g (%.3f %%FS)\n', ...
    p4(1), p4(2), p4(1) * 1000, R2_4, lin4 * 1000, 100 * lin4 / CAP);
fprintf('vs calibration: zero %+.1f mV, sensitivity %+.2f %%; error trend %.1f g/kg + %.1f g\n', ...
    1000 * (p4(2) - cal.V0), 100 * (p4(1) / cal.S - 1), pe(1), pe(2));
writetable(T, fullfile(repDir, 'lc_validation.csv'));

%% 2. Figure: error against the digital scale, calibration runs vs validation run
fig = U.figure('Validation', 540);
ax = axes(fig);
U.axes(ax);
yline(ax, 0, '-', 'Color', U.grey, 'LineWidth', 1.0, 'HandleVisibility', 'off');
h = gobjects(5, 1);
for r = 1:3
    k = Tc.Run == r;
    c = U.pale(U.run(r, :), 0.35);
    h(r) = plot(ax, Tc.Mass_kg(k), 1000 * Tc.Err_kg(k), U.marker{r}, 'Color', c, 'MarkerFaceColor', c, 'MarkerSize', 6, ...
        'DisplayName', sprintf('Run %d', r));
end
mm = [0 10];
h(5) = plot(ax, mm, polyval(pe, mm), '--', 'Color', U.ink, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('Linear fit of run 4: e = %.1fm + %.1f g', pe));
plot(ax, m, T.Err_g, '-', 'Color', U.ink, 'LineWidth', 1.0, 'HandleVisibility', 'off');
h(4) = plot(ax, m, T.Err_g, 'o', 'Color', U.ink, 'MarkerFaceColor', U.ink, 'MarkerSize', 8, ...
    'DisplayName', 'Run 4 (validation)');
xlim(ax, [-0.3 10.3]);
ylim(ax, [-110 300]);
xlabel(ax, 'Mass on the Digital Scale m (kg)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'Error m_{load cell} - m_{scale} (g)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'Error vs Digital Scale: Calibration Runs 1-3 and Validation Run 4', 'FontSize', 13, 'FontWeight', 'bold');
legend(ax, h, 'Location', 'northwest', 'FontSize', 9.5, 'Box', 'on');
U.save(fig, fullfile(figDir, 'lc_validation'));
