%% LC_REALTIME_REPLAY Replay the recorded A0 through sensorExpoler_loadcell.slx (real-time weight output).
%  The 33 recordings of runs 1-3 (each 10 s at 1 kHz, one load per file) are joined in loading
%  order, 0 -> 9.84 kg for run 1, then run 2, then run 3, after dropping the first 0.1 s of each file
%  (ADC/USB start-up). A copy of the model is made in a temporary folder, Host Serial Rx is replaced by
%  a From Workspace block carrying this A0 stream at 1 kHz, and the copy is simulated; the saved model
%  is not changed. Logged: voltage(mV), filtered voltage(mV), weight(N), mass(kg).
%  The jump between two files is instantaneous because each load was logged separately.
%  Writes Results/lc_realtime_replay.csv (mean output of each load against the digital scale).
%
% Compatible with MATLAB R2023a through R2026a (needs the Waijung library on the path to load the model).

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = lc_report_style();
G_ACC = 9.81;
T_SKIP = 0.1;      % s dropped at the start of each file
T_AVG  = 1.0;      % s ignored after each jump when averaging the output (moving average 0.512 s)

%% 1. A0 stream in loading order
[T, sig] = load_lc_runs(dataDir);
a = [];  ref = [];  seg = [];
for k = 1:height(T)
    keep = sig(k).t >= T_SKIP;
    a = [a; sig(k).A0(keep)]; %#ok<AGROW>
    ref = [ref; repmat(T.Mass_kg(k), nnz(keep), 1)]; %#ok<AGROW>
    seg = [seg; repmat(k, nnz(keep), 1)]; %#ok<AGROW>
end
t = (0:numel(a) - 1)' * 1e-3;

%% 2. Simulate a copy of the model
mdl0 = 'sensorExpoler_loadcell';
mdl  = 'loadcell_replay';
workDir = fullfile(tempdir, 'loadcell_replay');
if ~exist(workDir, 'dir'), mkdir(workDir); end
addpath(workDir);
fileGen = Simulink.fileGenControl('getConfig');
Simulink.fileGenControl('set', 'CacheFolder', workDir, 'CodeGenFolder', workDir);   % keep .slxc/slprj out of the repo
cleanupObj = onCleanup(@() restore(workDir, fileGen));

if bdIsLoaded(mdl), close_system(mdl, 0); end
copyfile(fullfile(rootDir, 'Simulink', [mdl0 '.slx']), fullfile(workDir, [mdl '.slx']), 'f');
load_system(fullfile(workDir, [mdl '.slx']));
swap_source(mdl);
set_param(mdl, 'StopTime', num2str(t(end)), 'FixedStep', '1e-3', 'SignalLogging', 'on', ...
    'UnconnectedInputMsg', 'none', 'UnconnectedOutputMsg', 'none', 'UnconnectedLineMsg', 'none');
simIn = Simulink.SimulationInput(mdl);
simIn = simIn.setVariable('rawA0', timeseries(uint16(a), t));
out = sim(simIn);
logs = out.get(get_param(mdl, 'SignalLoggingName'));
close_system(mdl, 0);

[vRaw, tl] = logged(logs, 'voltage(mV)');
vF = logged(logs, 'filtered voltage(mV)');
F  = logged(logs, 'weight(N)');
mk = logged(logs, 'mass(kg)');
idx = min(round(tl / 1e-3) + 1, numel(t));
refN = ref(idx) * G_ACC;
segL = seg(idx);

%% 3. Mean output of each load against the digital scale
R = table();
for k = 1:height(T)
    in = segL == k;
    t0 = tl(find(in, 1));
    use = in & tl >= t0 + T_AVG;
    if k == find(T.File == "8.883kg_1.mat")
        tk = tl(in) - t0 + T_SKIP;                       % time inside the original file
        ti = tl(in);
        use = use & ~ismember(tl, ti(tk >= 1.7 & tk <= 4.6));   % bump + moving-average tail
    end
    R = [R; table(T.Run(k), T.Mass_kg(k), T.Mass_kg(k) * G_ACC, mean(F(use)), std(F(use)), mean(mk(use)), ...
        'VariableNames', {'Run', 'Mass_scale_kg', 'F_scale_N', 'F_model_N', 'F_model_std_N', 'm_model_kg'})]; %#ok<AGROW>
end
R.Err_N = R.F_model_N - R.F_scale_N;
R.Err_pctFS = 100 * R.Err_N / (10 * G_ACC);
disp(R);
fprintf('Output error: max abs %.3f N (%.2f %%FS), RMSE %.3f N; filtered noise SD %.3f N (mean)\n', ...
    max(abs(R.Err_N)), max(abs(R.Err_pctFS)), sqrt(mean(R.Err_N.^2)), mean(R.F_model_std_N));
writetable(R, fullfile(repDir, 'lc_realtime_replay.csv'));

%% 4. Figure
fig = U.figure('Real-time replay', 680);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
runEnd = arrayfun(@(r) tl(find(T.Run(segL) == r, 1, 'last')), unique(T.Run));

ax1 = nexttile(tlo);
U.axes(ax1);
hR = plot(ax1, tl, vRaw / 1000, '-', 'Color', U.pale(U.run(1, :), 0.6), 'LineWidth', 0.5, ...
    'DisplayName', 'raw, 1 kHz');
hF = plot(ax1, tl, vF / 1000, '-', 'Color', U.run(1, :), 'LineWidth', 1.6, 'DisplayName', 'moving average (512 samples)');
for x = runEnd(1:end - 1)', xline(ax1, x, ':', 'Color', U.grey, 'LineWidth', 1.2, 'HandleVisibility', 'off'); end
ylim(ax1, [0 3.9]);
ylabel(ax1, 'Input V (V)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax1, '(a) Input voltage (recorded A0 replayed at 1 kHz)', 'FontSize', 12, 'FontWeight', 'bold');
legend(ax1, [hR hF], 'Location', 'northwest', 'FontSize', 9.5, 'Box', 'on');

ax2 = nexttile(tlo);
U.axes(ax2);
hO = plot(ax2, tl, F, '-', 'Color', U.run(2, :), 'LineWidth', 1.6, 'DisplayName', 'calc\_Weight output');
hS = stairs(ax2, tl, refN, '--', 'Color', U.ink, 'LineWidth', 1.2, 'DisplayName', 'Digital scale m \times g');
for x = runEnd(1:end - 1)', xline(ax2, x, ':', 'Color', U.grey, 'LineWidth', 1.2, 'HandleVisibility', 'off'); end
for r = 1:numel(runEnd)
    text(ax2, runEnd(r) - 6, 8, sprintf('Run %d', r), 'HorizontalAlignment', 'right', 'FontSize', 10, 'FontWeight', 'bold');
end
ylim(ax2, [-5 135]);
xlabel(ax2, 'Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax2, 'Weight F (N)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax2, '(b) Output weight in newtons (SI derived unit)', 'FontSize', 12, 'FontWeight', 'bold');
legend(ax2, [hO hS], 'Location', 'northwest', 'FontSize', 9.5, 'Box', 'on');
linkaxes([ax1 ax2], 'x');
xlim(ax2, [0 tl(end)]);
U.save(fig, fullfile(figDir, 'lc_realtime'));

%% ---------------------------------------------------------------- helpers
function swap_source(mdl)
% Host Serial Rx -> From Workspace on A0 (the other channels are left unconnected).
pos = get_param([mdl '/Host Serial Rx'], 'Position');
delete_block([mdl '/Host Serial Rx']);
delete_block([mdl '/Host Serial Setup']);
delete_line(find_system(mdl, 'FindAll', 'on', 'Type', 'line', 'Connected', 'off'));
add_block('simulink/Sources/From Workspace', [mdl '/rawA0'], 'Position', [pos(1) pos(2) + 230 pos(1) + 120 pos(2) + 270], ...
    'VariableName', 'rawA0', 'SampleTime', '1e-3', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_line(mdl, 'rawA0/1', 'Divide/1', 'autorouting', 'smart');
end

function restore(workDir, fileGen)
Simulink.fileGenControl('set', 'CacheFolder', fileGen.CacheFolder, 'CodeGenFolder', fileGen.CodeGenFolder);
rmpath(workDir);
end

function [x, t] = logged(logs, name)
v = logs.getElement(name).Values;
x = double(v.Data(:));
t = v.Time(:);
end
