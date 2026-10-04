%% LC_GAIN_SATURATION Gain design of the INA125 and the saturation it sets.
%  The bridge (input-referred) output is taken from the calibration line divided by the
%  design gain:  v_d(m) = v_off + s_b * m,  v_off = V0 / G,  s_b = S / G.
%  Gain design (Load cell.xlsx): bridge output measured with a multimeter = 6.3 mV with 9.843 kg
%  on the load cell, target output 3.0 V (below the 3.3 V ADC full scale)
%  -> G = 3.0 / 6.3 mV = 476,  RG = 60 kOhm / (G - 4) = 127 Ohm (trimpot set to 127 Ohm).
%  For any gain the output is G * v_d(m), clipped by the ADC at 3.3 V, so the load that
%  saturates the reading is  m_sat(G) = (3.3 / G - v_off) / s_b.
%  (a) G vs RG of the INA125, design point and the largest gain that still reads 10 kg.
%  (b) Output vs mass for four gains with the 3.3 V clip; measured points on G = 476.
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = lc_report_style();
L = load(fullfile(repDir, 'lc_calibration.mat'));   % from lc_calibration.m
cal = L.cal;  T = L.T;

VADC = 3.3;   CAP = 10;   VFS = 3.0;   DVM = 6.3e-3;   MM = 9.843;   % measured v_d at mass MM
gainOf = @(rg) 4 + 60e3 ./ rg;
rgOf   = @(g) 60e3 ./ (g - 4);

Gd    = VFS / DVM;               % design gain from the measured 6.3 mV
RGd   = rgOf(Gd);
G     = cal.gain;                % gain with the trimpot at 127 Ohm
s_b   = cal.S / G;               % V/kg at the bridge
v_off = cal.V0 / G;              % V at the bridge, zero load
vd10  = v_off + s_b * CAP;
Gmax  = VADC / vd10;             % largest gain that does not clip at 10 kg
RGmin = rgOf(Gmax);
msat  = @(g) (VADC ./ g - v_off) / s_b;
res_g = @(g) 3.3 / 4095 ./ (g * s_b) * 1000;   % grams per ADC count

fprintf('Design: G = %.1f -> RG = %.1f Ohm (trimpot set to 127 Ohm -> G = %.1f)\n', Gd, RGd, G);
fprintf('Bridge: v_off = %.3f mV, s_b = %.4f mV/kg, v_d(10 kg) = %.3f mV\n', v_off * 1e3, s_b * 1e3, vd10 * 1e3);
Vmm = cal.V0 + cal.S * MM;
fprintf('Check at %.3f kg: model v_d = %.3f mV (measured %.1f mV); output %.3f V (design %.1f V)\n', ...
    MM, (v_off + s_b * MM) * 1e3, DVM * 1e3, Vmm, VFS);
fprintf('  -> gain implied by the 6.3 mV reading: G = %.1f, RG = %.1f Ohm\n', Vmm / DVM, rgOf(Vmm / DVM));
fprintf('Saturation at G = %.0f: m_sat = %.2f kg (%.0f %% of capacity); output at 10 kg = %.3f V\n', ...
    G, msat(G), 100 * msat(G) / CAP, G * vd10);
fprintf('Largest gain reading 10 kg: G = %.1f, RG = %.1f Ohm\n', Gmax, RGmin);
gl = [100 300 476 700 1000];
for g = gl
    fprintf('  G = %5.0f  RG = %7.1f Ohm  V(0) = %.3f V  m_sat = %6.2f kg  res = %.2f g/count\n', ...
        g, rgOf(g), g * v_off, msat(g), res_g(g));
end

fig = U.figure('Gain and saturation', 720);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

%% (a) G vs RG
ax1 = nexttile(tl);
U.axes(ax1);
rg = logspace(1, 5, 400);
patch(ax1, [10 RGmin RGmin 10], [1 1 1e4 1e4], [0.92 0.92 0.92], 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(ax1, 12, 4, sprintf('R_G < %.0f \\Omega: output clips\nbefore 10 kg', RGmin), 'FontSize', 9.5, ...
    'Color', [0.35 0.35 0.35]);
plot(ax1, rg, gainOf(rg), '-', 'Color', U.run(1, :), 'LineWidth', 2.0, 'DisplayName', 'G = 4 + 60 k\Omega / R_G');
plot(ax1, RGd, Gd, 'o', 'Color', U.ink, 'MarkerFaceColor', U.run(2, :), 'MarkerSize', 9, ...
    'DisplayName', sprintf('Design: R_G = %.0f \\Omega, G = %.0f', RGd, Gd));
plot(ax1, RGmin, Gmax, 's', 'Color', U.ink, 'MarkerFaceColor', U.run(3, :), 'MarkerSize', 8, ...
    'DisplayName', sprintf('Limit: R_G = %.0f \\Omega, G = %.0f', RGmin, Gmax));
set(ax1, 'XScale', 'log', 'YScale', 'log', 'XMinorGrid', 'off', 'YMinorGrid', 'off');
xlim(ax1, [10 1e5]);  ylim(ax1, [1 1e4]);
xlabel(ax1, 'Gain Resistor R_G (\Omega)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax1, 'INA125 Gain G', 'FontSize', 12, 'FontWeight', 'bold');
title(ax1, '(a) INA125 Gain vs Gain-Setting Resistor', 'FontSize', 12, 'FontWeight', 'bold');
legend(ax1, 'Location', 'northeast', 'FontSize', 10, 'Box', 'on');

%% (b) Output vs mass for several gains, ADC clip at 3.3 V
ax2 = nexttile(tl);
U.axes(ax2);
mm = linspace(0, 12, 600);
gs = [300 G 700 1000];
cs = [U.run(1, :); U.ink; U.run(2, :); U.run(3, :)];
ls = {'-', '--', '-', '-'};
h = gobjects(numel(gs) + 1, 1);
for i = 1:numel(gs)
    v = min(gs(i) * (v_off + s_b * mm), VADC);
    h(i) = plot(ax2, mm, v, ls{i}, 'Color', cs(i, :), 'LineWidth', 2.0, ...
        'DisplayName', sprintf('G = %.0f (R_G = %.0f \\Omega)', gs(i), rgOf(gs(i))));
    if msat(gs(i)) < 12
        plot(ax2, msat(gs(i)), VADC, 'v', 'Color', U.ink, 'MarkerFaceColor', cs(i, :), 'MarkerSize', 8, ...
            'HandleVisibility', 'off');
        text(ax2, msat(gs(i)), VADC - 0.16, sprintf('%.1f kg', msat(gs(i))), 'FontSize', 9.5, ...
            'HorizontalAlignment', 'center', 'Color', [0.2 0.2 0.2]);
    end
end
h(end) = plot(ax2, T.Mass_kg, T.V_mean, 'o', 'Color', U.ink, 'MarkerFaceColor', 'w', 'MarkerSize', 5, ...
    'DisplayName', 'Measured (runs 1-3, G = 476)');
xline(ax2, CAP, ':', 'Rated 10 kg', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.2, 'FontSize', 9.5, ...
    'LabelVerticalAlignment', 'top', 'LabelOrientation', 'horizontal', 'HandleVisibility', 'off');
yline(ax2, VADC, ':', 'ADC full scale 3.3 V', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.2, 'FontSize', 9.5, ...
    'LabelHorizontalAlignment', 'left', 'LabelVerticalAlignment', 'top', 'HandleVisibility', 'off');
xlim(ax2, [0 12]);  ylim(ax2, [0 3.7]);
xlabel(ax2, 'Mass m (kg)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax2, 'Output Read by the ADC (V)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax2, '(b) Output vs Mass for Different Gains (Clipped at 3.3 V)', 'FontSize', 12, 'FontWeight', 'bold');
legend(ax2, h, 'Location', 'southeast', 'FontSize', 9.5, 'Box', 'on');
U.save(fig, fullfile(figDir, 'lc_gain_saturation'));
