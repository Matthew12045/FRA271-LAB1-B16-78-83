%% SCHMITT_TRIGGER_REPLAY Replay the recorded Linear Poten 2 signal through the Schmitt Trigger model
%  Feeds the A0 samples recorded in Data/schmitt.mat into a copy of
%  sensorExpoler_poten.slx (Host Serial Rx replaced by From Workspace), so the
%  Schmitt Trigger circuit can be evaluated with the current resistor values.
%
%  Threshold check: for every transition the true threshold lies between the
%  last input value before the output switched and the input value at the switch.
%
% Outputs:
%   - Figures/Schmitt Trigger/schmitt_trigger_replay_time_domain.png (600 DPI)
%   - Results/schmitt_trigger_replay_metrics.csv
%
% Compatible with MATLAB R2020a through R2026a.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
if endsWith(thisDir, 'Scripts'), rootDir = fileparts(thisDir); else, rootDir = thisDir; end
figDir = fullfile(rootDir, 'Figures', 'Schmitt Trigger');
repDir = fullfile(rootDir, 'Results');

T_START = 40.0;   % active sweep window (same as schmitt_trigger_analysis.m)
T_END   = 100.0;

%% 1. Build the replay model in a temporary folder
srcModel = fullfile(rootDir, 'Simulink', 'sensorExpoler_poten.slx');
workDir  = fullfile(tempdir, 'schmitt_replay');
if ~exist(workDir, 'dir'), mkdir(workDir); end
mdl = 'schmitt_replay';
if bdIsLoaded(mdl), close_system(mdl, 0); end
copyfile(srcModel, fullfile(workDir, [mdl '.slx']), 'f');
addpath(workDir);
cleanupObj = onCleanup(@() rmpath(workDir));
load_system(fullfile(workDir, [mdl '.slx']));

S = load(fullfile(rootDir, 'Data', 'schmitt.mat'));
a0 = S.data.getElement('A0').Values;
a0ts = timeseries(double(a0.Data(:)), a0.Time(:)); %#ok<NASGU> used by From Workspace

pos = get_param([mdl '/Cast To Double'], 'Position');
delete_block([mdl '/Host Serial Rx']);
delete_block([mdl '/Host Serial Setup']);
delete_block([mdl '/Cast To Double']);
add_block('simulink/Sources/From Workspace', [mdl '/A0src'], 'Position', pos, ...
    'VariableName', 'a0ts', 'SampleTime', '1e-3', 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value');
delete_line(find_system(mdl, 'FindAll', 'on', 'Type', 'line', 'Connected', 'off'));
pc = get_param([mdl '/Divide'], 'PortConnectivity');
if pc(1).SrcBlock ~= get_param([mdl '/A0src'], 'Handle')
    ph = get_param([mdl '/Divide'], 'PortHandles');
    ah = get_param([mdl '/A0src'], 'PortHandles');
    add_line(mdl, ah.Outport(1), ph.Inport(1), 'autorouting', 'on');
end
set_param(mdl, 'StopTime', num2str(T_END + 5), 'SignalLogging', 'on');

Rin = str2double(get_param([mdl '/Rin'], 'R')) * 1e3;
Rh  = str2double(get_param([mdl '/Rh'],  'R')) * 1e3;
fprintf('Replaying schmitt.mat through the model (Rin = %.2f kOhm, Rh = %.0f kOhm)...\n', Rin/1e3, Rh/1e3);

%% 2. Simulate
simIn = Simulink.SimulationInput(mdl);
simIn = simIn.setVariable('a0ts', timeseries(double(a0.Data(:)), a0.Time(:)));
out = sim(simIn);
logs = out.get(get_param(mdl, 'SignalLoggingName'));
vin  = logs.getElement('voltage(V)').Values;
vout = logs.getElement('schmitt trigger').Values;
close_system(mdl, 0);

tv = vin.Time(:);  v = double(vin.Data(:));
ts = vout.Time(:); s = double(vout.Data(:));

%% 3. Theoretical thresholds (non-inverting comparator with hysteresis)
Vdd = 3.3; Vref = Vdd/2; Vos = 5e-3; Voh = 3.3; Vol = 0;
k   = Rin / Rh;
Vth = (Vref + Vos) * (1 + k) - Vol * k;
Vtl = (Vref + Vos) * (1 + k) - Voh * k;

%% 4. Transitions and threshold brackets inside the active window
st = s > Vref;
d  = diff(st);
up = find(d ==  1) + 1;
dn = find(d == -1) + 1;
evType = {}; evTime = []; evLo = []; evHi = [];
for i = up(:)'
    t0 = ts(i);
    if t0 < T_START || t0 > T_END, continue; end
    prev = max([0; ts(dn(dn < i))]);
    evType{end+1, 1} = 'LOW->HIGH'; %#ok<SAGROW>
    evTime(end+1, 1) = t0; %#ok<SAGROW>
    evLo(end+1, 1)   = max(v(tv > prev & tv < t0)); %#ok<SAGROW>
    evHi(end+1, 1)   = v(find(tv >= t0, 1)); %#ok<SAGROW>
end
for i = dn(:)'
    t0 = ts(i);
    if t0 < T_START || t0 > T_END, continue; end
    prev = max([0; ts(up(up < i))]);
    evType{end+1, 1} = 'HIGH->LOW'; %#ok<SAGROW>
    evTime(end+1, 1) = t0; %#ok<SAGROW>
    evLo(end+1, 1)   = v(find(tv >= t0, 1)); %#ok<SAGROW>
    evHi(end+1, 1)   = min(v(tv > prev & tv < t0)); %#ok<SAGROW>
end
[evTime, ord] = sort(evTime);
evType = evType(ord); evLo = evLo(ord); evHi = evHi(ord);
isUp = strcmp(evType, 'LOW->HIGH');

fprintf('Transitions in window: %d (%d rising, %d falling)\n', numel(evTime), sum(isUp), sum(~isUp));
fprintf('V_TH: theory %.5f V | data bracket (%.5f, %.5f]\n', Vth, max(evLo(isUp)), min(evHi(isUp)));
fprintf('V_TL: theory %.5f V | data bracket [%.5f, %.5f)\n', Vtl, max(evLo(~isUp)), min(evHi(~isUp)));
fprintf('Hysteresis: theory %.2f mV\n', (Vth - Vtl) * 1e3);

writetable(table((1:numel(evTime))', evTime - T_START, evType, evLo, evHi, ...
    'VariableNames', {'Event_No', 'Time_s', 'Transition_Type', 'Bracket_Low_V', 'Bracket_High_V'}), ...
    fullfile(repDir, 'schmitt_trigger_replay_metrics.csv'));

%% 5. Time-domain figure (same layout as schmitt_trigger_analysis.m)
mi = tv >= T_START & tv <= T_END;
ms = ts >= T_START & ts <= T_END;
fig = figure('Color', 'w', 'Position', [70 70 1040 620]);
ax1 = subplot(2, 1, 1);
plot(ax1, tv(mi) - T_START, v(mi), '-', 'Color', [0.12 0.45 0.82], 'LineWidth', 1.8);
grid(ax1, 'on'); set(ax1, 'FontSize', 11, 'Box', 'on');
ylabel(ax1, 'Input Voltage V_{in} (V)', 'FontWeight', 'bold');
title(ax1, sprintf('Linear Potentiometer 2 Input & Schmitt Trigger Output (R_{in} = %.2f k\\Omega, R_h = %.0f k\\Omega)', Rin/1e3, Rh/1e3));
ylim(ax1, [-0.1 3.6]); xlim(ax1, [0 T_END - T_START]);
ax2 = subplot(2, 1, 2);
plot(ax2, ts(ms) - T_START, s(ms), '-', 'Color', [0.85 0.22 0.18], 'LineWidth', 1.8);
grid(ax2, 'on'); set(ax2, 'FontSize', 11, 'Box', 'on');
ylabel(ax2, 'Schmitt Output V_{out} (V)', 'FontWeight', 'bold');
xlabel(ax2, 'Sweep Time (seconds)', 'FontWeight', 'bold');
ylim(ax2, [-0.3 3.9]); yticks(ax2, [0 1.65 3.3]); xlim(ax2, [0 T_END - T_START]);
exportgraphics(fig, fullfile(figDir, 'schmitt_trigger_replay_time_domain.png'), 'Resolution', 600);
fprintf('Saved figure and metrics.\n');
