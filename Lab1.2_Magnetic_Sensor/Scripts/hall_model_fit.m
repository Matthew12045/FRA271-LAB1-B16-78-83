%% HALL_MODEL_FIT Fit the far-field (dipole) form of the cylinder-magnet model to the data.
%  For z >> R, D the on-axis cylinder field B(z) = Br/2 [ (D+z)/sqrt(R^2+(D+z)^2) - z/sqrt(R^2+z^2) ]
%  reduces to B = C / (z + z0)^3, with C = Br R^2 D / 2 and z0 the offset between the
%  distance scale and the magnet. North and South are fitted jointly:
%      Vout = VQ -/+ S * C / (z + z0)^3      (North: minus, South: plus)
%  with one C, one VQ and a separate z0 per pole (the magnet is removed and re-inserted
%  to change pole, which shifts its face slightly). Only points inside VL are fitted.
%
% Compatible with MATLAB R2020a through R2026a (fminsearch, no toolbox needed).

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end
outBase = fullfile(figDir, 'model_fit_unshielded');

H = load_hall_sweeps(rootDir);
d = H.d;

fits = struct();
for sh = {'', '_Sh'}
    N = H.(['North' sh{1}]);
    S = H.(['South' sh{1}]);
    fits.(['f' sh{1}]) = fit_dipole(d, mean(N.V, 2), mean(S.V, 2), N.linear, S.linear, H.S);
end
F  = fits.f;
Fs = fits.f_Sh;
T = table(["Unshielded"; "Shielded"], [F.C; Fs.C], [F.z0N; Fs.z0N], [F.z0S; Fs.z0S], [F.VQ; Fs.VQ], ...
    [F.R2N; Fs.R2N], [F.R2S; Fs.R2S], [F.rms; Fs.rms], ...
    'VariableNames', {'Condition', 'C_mTcm3', 'z0_North_cm', 'z0_South_cm', 'VQ_fit_mV', ...
                      'R2_North', 'R2_South', 'RMS_residual_mV'});
writetable(T, fullfile(repDir, 'hall_model_fit.csv'));
disp(T);

%% Figure: unshielded data and fitted model (clipped at the measured output rails)
vn = mean(H.North.V, 2);
vs = mean(H.South.V, 2);
railLo = min(vn);
railHi = max(vs);
zf = linspace(0.05, 3.9, 400)';
vnModel = max(F.VQ - H.S * F.C ./ (zf + F.z0N).^3, railLo);
vsModel = min(F.VQ + H.S * F.C ./ (zf + F.z0S).^3, railHi);

northC = [0.12 0.45 0.80];
southC = [0.85 0.22 0.18];

fig = figure('Color', 'w', 'Position', [100 100 860 560], 'Name', 'Model fit (unshielded)');
set(fig, 'DefaultTextInterpreter', 'tex', ...
         'DefaultAxesTickLabelInterpreter', 'tex', ...
         'DefaultLegendInterpreter', 'tex');
ax = axes(fig);
hold(ax, 'on');
set(ax, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
grid(ax, 'on');
yyaxis(ax, 'left');
yl = [0 3400];

patch(ax, [0 4 4 0], [yl(1) yl(1) H.VL(1) H.VL(1)], [0.90 0.90 0.90], 'EdgeColor', 'none', 'HandleVisibility', 'off');
patch(ax, [0 4 4 0], [H.VL(2) H.VL(2) yl(2) yl(2)], [0.90 0.90 0.90], 'EdgeColor', 'none', 'HandleVisibility', 'off');
text(ax, 1.0, mean([H.VL(2) yl(2)]), 'Outside V_L (saturation)', 'FontSize', 9.5, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'middle');
text(ax, 1.0, mean([yl(1) H.VL(1)]), 'Outside V_L (saturation)', 'FontSize', 9.5, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'middle');
hQ = plot(ax, [0 4], [F.VQ F.VQ], ':', 'Color', [0.30 0.30 0.30], 'LineWidth', 1.4, ...
    'DisplayName', sprintf('V_Q (fit) = %.0f mV', F.VQ));

hMN = plot(ax, zf, vnModel, '-', 'Color', northC, 'LineWidth', 1.8, 'DisplayName', 'North, model');
hMS = plot(ax, zf, vsModel, '-', 'Color', southC, 'LineWidth', 1.8, 'DisplayName', 'South, model');
ln = H.North.linear;  ls = H.South.linear;
hDN = plot(ax, d(ln), vn(ln), 'o', 'MarkerSize', 6.5, 'MarkerFaceColor', northC, 'MarkerEdgeColor', northC * 0.7, ...
    'DisplayName', 'North, measured');
plot(ax, d(~ln), vn(~ln), 'o', 'MarkerSize', 6.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', northC, 'HandleVisibility', 'off');
hDS = plot(ax, d(ls), vs(ls), 's', 'MarkerSize', 6.5, 'MarkerFaceColor', southC, 'MarkerEdgeColor', southC * 0.7, ...
    'DisplayName', 'South, measured');
plot(ax, d(~ls), vs(~ls), 's', 'MarkerSize', 6.5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', southC, 'HandleVisibility', 'off');

ylim(ax, yl);
yticks(ax, 0:500:3000);
ylabel(ax, 'Output Voltage V_{out} (mV)', 'FontSize', 12, 'FontWeight', 'bold');
ax.YAxis(1).Color = [0.15 0.15 0.15];
yyaxis(ax, 'right');
ylim(ax, (yl - H.VQ) / H.S);
ylabel(ax, 'Magnetic Flux Density B (mT)', 'FontSize', 12, 'FontWeight', 'bold');
ax.YAxis(2).Color = [0.15 0.15 0.15];
yyaxis(ax, 'left');

xlim(ax, [0 4]);
xticks(ax, 0:0.5:4);
xlabel(ax, 'Distance z (cm)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax, 'DRV5055A2: Measured V_{out} vs. Dipole Model (Unshielded)', 'FontSize', 13, 'FontWeight', 'bold');
legend(ax, [hDN hMN hDS hMS hQ], 'Location', 'northeast', 'FontSize', 10, 'Box', 'on');

annotationText = sprintf(['\\bfDipole Fit: B = C / (z + z_0)^3\\rm\n', ...
    'C = %.1f mT\\cdotcm^3\n', ...
    'z_0 = %.2f cm (North), %.2f cm (South)\n', ...
    'V_Q (fit) = %.0f mV (datasheet 1590 - 1710 mV)\n', ...
    'R^2 = %.4f (North), %.4f (South)'], F.C, F.z0N, F.z0S, F.VQ, F.R2N, F.R2S);
hAnn = annotation(fig, 'textbox', [0 0 0.1 0.1], 'String', annotationText, 'FitBoxToText', 'on', ...
    'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
    'FontSize', 9.5, 'Margin', 5);
drawnow;
axPos  = ax.Position;
annPos = hAnn.Position;
pad    = 0.012;
% Bottom-right, just above the lower saturation band
bandTop = axPos(2) + axPos(4) * (H.VL(1) - yl(1)) / diff(yl);
hAnn.Position = [axPos(1) + axPos(3) - annPos(3) - pad, bandTop + pad, annPos(3), annPos(4)];

hold(ax, 'off');
drawnow;
exportgraphics(fig, [outBase '.png'], 'Resolution', 600);
savefig(fig, [outBase '.fig']);
fprintf('Saved %s.png\n', outBase);

%% ---------------------------------------------------------------- helpers
function F = fit_dipole(d, vn, vs, ln, ls, S)
% Least-squares fit of Vout = VQ -/+ S*C/(z+z0)^3 to the North / South means (points inside VL).
model = @(C, z0, z) C ./ (z + z0).^3;
res = @(p) [vn(ln) - (p(4) - S * model(p(1), p(2), d(ln))); ...
            vs(ls) - (p(4) + S * model(p(1), p(3), d(ls)))];
opts = optimset('MaxFunEvals', 4e4, 'MaxIter', 4e4, 'TolX', 1e-10, 'TolFun', 1e-10);
p = fminsearch(@(p) sum(res(p).^2), [100, 0.4, 0.4, 1650], opts);
r = res(p);
rn = r(1:sum(ln));
rs = r(sum(ln) + 1:end);
F.C   = p(1);
F.z0N = p(2);
F.z0S = p(3);
F.VQ  = p(4);
F.R2N = 1 - sum(rn.^2) / sum((vn(ln) - mean(vn(ln))).^2);
F.R2S = 1 - sum(rs.^2) / sum((vs(ls) - mean(vs(ls))).^2);
F.rms = sqrt(mean(r.^2));
end
