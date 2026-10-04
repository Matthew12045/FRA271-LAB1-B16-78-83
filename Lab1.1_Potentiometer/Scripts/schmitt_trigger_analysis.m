%% SCHMITT_TRIGGER_ANALYSIS Plot Real-Time Signal Change & Schmitt Trigger Activation
%  Analyzes potentiometer analog voltage vs. Schmitt trigger response based on
%  the sensorExpoler_poten.slx Simscape circuit architecture:
%    - Supply Voltage: Vdd = 3.30 V
%    - Voltage Divider Reference: Rx = 10.0 kOhm, Ry = 10.0 kOhm -> Vref = 1.650 V
%    - Input Series Resistor: Rin = 3.9 kOhm
%    - Positive Feedback Resistor: Rh = 576.0 kOhm
%    - Comparator Input Offset: Vos = 5.0 mV
%    - Output Saturation Limits: Vol = 0.00 V, Voh = 3.30 V
%
% Visualizations:
%   1. Figure 1: Synchronized Dual-Panel Time-Domain Dashboard (Vin, Vout, Thresholds, Events)
%   2. Figure 2: Transfer Characteristic & Zoomed Hysteresis Loop (Full scale + Hysteresis Band)
%   3. Figure 3: Interactive Real-Time Playback Oscilloscope with Live State HUD
%
% Outputs:
%   - Figures/Schmitt Trigger/schmitt_trigger_time_domain.png (600 DPI)
%   - Figures/Schmitt Trigger/schmitt_trigger_time_domain.fig
%   - Figures/Schmitt Trigger/schmitt_trigger_hysteresis.png (600 DPI)
%   - Figures/Schmitt Trigger/schmitt_trigger_hysteresis.fig
%   - Results/schmitt_trigger_metrics.csv
%
% Compatible with MATLAB R2020a through R2026a and MATLAB Agentic AI Toolkit.

clear; close all; clc;

%% 0. Configuration & Data Trimming Options
ENABLE_ANIMATION  = false; % Set to true to launch interactive real-time playback
PLAYBACK_SPEED    = 3.0;   % Playback speed multiplier (e.g. 3x real-time for active record)
TRIM_DATA         = true;  % Cut out unnecessary idle startup (0-40s) and saturated tail (100-126s)
TRIM_START_TIME   = 40.0;  % Active potentiometer sweep start time in seconds
TRIM_END_TIME     = 100.0; % Active potentiometer sweep end time in seconds
RESET_TIME_ORIGIN = true;  % Reset active window time axis to start at t = 0 s

% Visual Layout Display Toggles (Configurable)
SHOW_SIDEBAR_CARD  = false; % Remove right sidebar text card (default: false)
SHOW_THRESHOLDS    = false; % Remove Vth / Vtl dashed lines & hysteresis band (default: false)
SHOW_ACTIVATION    = false; % Remove trigger activated / deactivated triangle markers (default: false)
SHOW_PULSE_SHADING = false; % Remove shaded fill under Schmitt pulse (default: false)

%% 1. Workspace Directory Setup
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
if endsWith(thisDir, 'Scripts'), rootDir = fileparts(thisDir); else, rootDir = thisDir; end

figDir = fullfile(rootDir, 'Figures', 'Schmitt Trigger');
repDir = fullfile(rootDir, 'Results');
if ~exist(figDir, 'dir'), mkdir(figDir); end
if ~exist(repDir, 'dir'), mkdir(repDir); end

fprintf('========================================================================\n');
fprintf(' SCHMITT TRIGGER SENSOR DYNAMICS & ACTIVATION ANALYSIS\n');
fprintf(' Built for MATLAB Agentic AI Toolkit & R2020a-R2026a Compliance\n');
fprintf(' Circuit Origin: sensorExpoler_poten.slx\n');
fprintf('========================================================================\n\n');

%% 2. Ingest Data from schmitt.mat
candidateMatPaths = {
    fullfile(rootDir, 'Data', 'schmitt.mat');
    fullfile(rootDir, 'schmitt.mat');
    fullfile(pwd, 'Data', 'schmitt.mat');
    fullfile(pwd, 'schmitt.mat');
};

matPath = '';
for k = 1:numel(candidateMatPaths)
    if exist(candidateMatPaths{k}, 'file')
        matPath = candidateMatPaths{k};
        break;
    end
end

if isempty(matPath)
    w = which('schmitt.mat');
    if ~isempty(w), matPath = w; end
end

if isempty(matPath)
    error('Could not locate "schmitt.mat". Please ensure it is in the Data/ folder or MATLAB path.');
end

fprintf('Loading dataset: %s ...\n', matPath);
S = load(matPath);

% Extract Simulink.SimulationData.Dataset object
if isfield(S, 'data')
    ds = S.data;
else
    fields = fieldnames(S);
    ds = S.(fields{1});
end

elemNames = {};
if isa(ds, 'Simulink.SimulationData.Dataset')
    elemNames = ds.getElementNames();
    fprintf('Detected Simulink Dataset with %d logged elements:\n', numel(elemNames));
    for i = 1:numel(elemNames)
        fprintf('  [%d] %s\n', i, elemNames{i});
    end
end

% Extract Analog Input Voltage Signal Vin(t)
v_in_raw = [];
t_in_raw = [];
if ismember('voltage(V)', elemNames)
    [t_in_raw, v_in_raw] = extractTimeSeries(ds.getElement('voltage(V)'));
    fprintf('-> Extracted "voltage(V)" as primary input signal.\n');
elseif ismember('voltage(mV)', elemNames)
    [t_in_raw, v_mv] = extractTimeSeries(ds.getElement('voltage(mV)'));
    v_in_raw = v_mv / 1000.0;
    fprintf('-> Extracted "voltage(mV)" and converted to Volts.\n');
elseif ismember('A0', elemNames)
    [t_in_raw, a0] = extractTimeSeries(ds.getElement('A0'));
    v_in_raw = (double(a0) / 4095.0) * 3.30;
    fprintf('-> Extracted "A0" (12-bit ADC) and mapped to [0, 3.30 V].\n');
else
    error('Could not find analog voltage signal in dataset.');
end

% Extract Schmitt Trigger Output Signal Vout(t)
v_sch_raw = [];
t_sch_raw = [];
schmittElemIdx = find(contains(elemNames, 'schmitt', 'IgnoreCase', true) | ...
                      contains(elemNames, 'trigger', 'IgnoreCase', true), 1);
if ~isempty(schmittElemIdx)
    schmittName = elemNames{schmittElemIdx};
    [t_sch_raw, v_sch_raw] = extractTimeSeries(ds.getElement(schmittName));
    fprintf('-> Extracted Schmitt trigger output from "%s".\n', schmittName);
else
    error('Could not find "schmitt trigger" signal in dataset.');
end

% Ensure column vectors & clean numeric types
t_in  = double(t_in_raw(:));
v_in  = double(v_in_raw(:));
t_sch = double(t_sch_raw(:));
v_sch = double(v_sch_raw(:));

%% 2.5 Data Trimming: Cut Out Unnecessary Idle & Saturated Sections
if TRIM_DATA
    fprintf('\nTrimming data: Removing initial idle (0 - %.1fs) and saturated tail (%.1f - %.1fs)...\n', ...
        TRIM_START_TIME, TRIM_END_TIME, max(t_in));
    mask_in  = (t_in >= TRIM_START_TIME) & (t_in <= TRIM_END_TIME);
    mask_sch = (t_sch >= TRIM_START_TIME) & (t_sch <= TRIM_END_TIME);
    
    t_in  = t_in(mask_in);
    v_in  = v_in(mask_in);
    t_sch = t_sch(mask_sch);
    v_sch = v_sch(mask_sch);
    
    if RESET_TIME_ORIGIN
        timeOffset = TRIM_START_TIME;
        t_in  = t_in - timeOffset;
        t_sch = t_sch - timeOffset;
        timeAxisLabel = 'Sweep Time (seconds) \rightarrow';
    else
        timeOffset = 0.0;
        timeAxisLabel = 'Original Time (seconds) \rightarrow';
    end
    fprintf('  Active sweep retained: [%.1f s, %.1f s] (Duration = %.1f s)\n', ...
        TRIM_START_TIME, TRIM_END_TIME, max(t_in));
    fprintf('  Retained samples: %d input samples (1 kHz), %d Schmitt samples (10 kHz)\n\n', ...
        numel(v_in), numel(v_sch));
else
    timeOffset = 0.0;
    timeAxisLabel = 'Time (seconds) \rightarrow';
    fprintf('Full dataset retained (Span = [0, %.2f] s)\n\n', max(t_in));
end

totalDuration = min(max(t_in), max(t_sch));

%% 3. Theoretical Simscape Circuit Model (sensorExpoler_poten.slx)
circuit.Vdd      = 3.30;       % V (System supply voltage)
circuit.Rx       = 10.0e3;     % Ohm (Upper voltage divider resistor)
circuit.Ry       = 10.0e3;     % Ohm (Lower voltage divider resistor)
circuit.Rin      = 3.9e3;      % Ohm (Input coupling series resistor)
circuit.Rh       = 576.0e3;    % Ohm (Positive feedback hysteresis resistor)
circuit.Vos      = 5.0e-3;     % V (Comparator input offset voltage)
circuit.Vol      = 0.00;       % V (Low output saturation level)
circuit.Voh      = 3.30;       % V (High output saturation level)

% Reference voltage at divider midpoint: Vref = Vdd * Ry / (Rx + Ry)
circuit.Vref     = circuit.Vdd * (circuit.Ry / (circuit.Rx + circuit.Ry)); % 1.650 V

% Non-inverting Schmitt trigger theoretical thresholds:
%   Vin = (Vref + Vos)*(1 + Rin/Rh) - Vout*(Rin/Rh)
circuit.Vth_theo = (circuit.Vref + circuit.Vos) * (1 + circuit.Rin / circuit.Rh) - circuit.Vol * (circuit.Rin / circuit.Rh);
circuit.Vtl_theo = (circuit.Vref + circuit.Vos) * (1 + circuit.Rin / circuit.Rh) - circuit.Voh * (circuit.Rin / circuit.Rh);
circuit.Vh_theo  = circuit.Vth_theo - circuit.Vtl_theo; % = (Voh - Vol) * (Rin / Rh)

fprintf('------------------------------------------------------------------------\n');
fprintf(' THEORETICAL CIRCUIT SPECIFICATIONS (sensorExpoler_poten.slx)\n');
fprintf('------------------------------------------------------------------------\n');
fprintf('  Supply Voltage (Vdd)         : %.2f V\n', circuit.Vdd);
fprintf('  Divider Resistors (Rx, Ry)   : %.1f kOhm, %.1f kOhm -> Vref = %.3f V\n', ...
    circuit.Rx/1e3, circuit.Ry/1e3, circuit.Vref);
fprintf('  Input Series Resistor (Rin)  : %.2f kOhm\n', circuit.Rin/1e3);
fprintf('  Feedback Resistor (Rh)       : %.1f kOhm (Feedback ratio: 1/%.1f)\n', ...
    circuit.Rh/1e3, circuit.Rh/circuit.Rin);
fprintf('  Comparator Offset (Vos)      : %.1f mV\n', circuit.Vos*1e3);
fprintf('  Upper Threshold (V_TH, theo) : %.4f V (%.1f mV)\n', circuit.Vth_theo, circuit.Vth_theo*1e3);
fprintf('  Lower Threshold (V_TL, theo) : %.4f V (%.1f mV)\n', circuit.Vtl_theo, circuit.Vtl_theo*1e3);
fprintf('  Hysteresis Width (Delta V_H) : %.4f V (%.2f mV)\n\n', circuit.Vh_theo, circuit.Vh_theo*1e3);

%% 4. Switching Event Detection & Empirical Hysteresis Analysis
v_mid = (max(v_sch) + min(v_sch)) / 2.0;
sch_state = v_sch >= v_mid;

diff_state = diff(sch_state);
idx_rising  = find(diff_state == 1) + 1;  % LOW -> HIGH (Activation)
idx_falling = find(diff_state == -1) + 1; % HIGH -> LOW (Deactivation)

t_rising  = t_sch(idx_rising);
t_falling = t_sch(idx_falling);

vin_at_rising  = interp1(t_in, v_in, t_rising, 'linear', 'extrap');
vin_at_falling = interp1(t_in, v_in, t_falling, 'linear', 'extrap');

nTransitions = numel(idx_rising) + numel(idx_falling);
nCycles      = min(numel(idx_rising), numel(idx_falling));

vth_meas_mean = mean(vin_at_rising);
vth_meas_std  = std(vin_at_rising);
vtl_meas_mean = mean(vin_at_falling);
vtl_meas_std  = std(vin_at_falling);
vh_meas       = vth_meas_mean - vtl_meas_mean;

fprintf('------------------------------------------------------------------------\n');
fprintf(' EMPIRICAL SCHMITT TRIGGER ACTIVATION METRICS (ACTIVE WINDOW)\n');
fprintf('------------------------------------------------------------------------\n');
fprintf('  Total Transitions Detected   : %d (%d rising, %d falling, %d complete cycles)\n', ...
    nTransitions, numel(idx_rising), numel(idx_falling), nCycles);
fprintf('  Measured Upper Threshold V_TH: %.4f +/- %.4f V (Theo: %.4f V, Diff: %+.1f mV)\n', ...
    vth_meas_mean, vth_meas_std, circuit.Vth_theo, (vth_meas_mean - circuit.Vth_theo)*1e3);
fprintf('  Measured Lower Threshold V_TL: %.4f +/- %.4f V (Theo: %.4f V, Diff: %+.1f mV)\n', ...
    vtl_meas_mean, vtl_meas_std, circuit.Vtl_theo, (vtl_meas_mean - circuit.Vtl_theo)*1e3);
fprintf('  Measured Hysteresis Width V_H: %.4f V (%.2f mV) [Theo: %.2f mV]\n\n', ...
    vh_meas, vh_meas*1e3, circuit.Vh_theo*1e3);

% Save CSV transition log
eventTypes  = [repmat({'Activation (LOW->HIGH)'}, numel(t_rising), 1); ...
               repmat({'Deactivation (HIGH->LOW)'}, numel(t_falling), 1)];
eventTimes  = [t_rising; t_falling];
eventVin    = [vin_at_rising; vin_at_falling];
eventVout   = [repmat(circuit.Voh, numel(t_rising), 1); repmat(circuit.Vol, numel(t_falling), 1)];

[eventTimes, sortIdx] = sort(eventTimes);
eventTypes = eventTypes(sortIdx);
eventVin   = eventVin(sortIdx);
eventVout  = eventVout(sortIdx);

eventTable = table((1:numel(eventTimes))', eventTimes, eventTypes, eventVin, eventVout, ...
    'VariableNames', {'Event_No', 'Time_s', 'Transition_Type', 'Vin_Switch_V', 'Vout_Target_V'});

outCsv = fullfile(repDir, 'schmitt_trigger_metrics.csv');
writetable(eventTable, outCsv);
fprintf('Saved active event transition log to:\n  - %s\n\n', outCsv);

%% 5. FIGURE 1: Time-Domain Synchronized Dashboard (Vin, Vout, Thresholds)
fig1 = figure('Color', 'w', 'Position', [70 70 1040 620], ...
    'Name', 'Potentiometer Signal & Schmitt Trigger Response (Active Sweeps)');
set(fig1, 'DefaultTextInterpreter', 'tex', ...
          'DefaultAxesTickLabelInterpreter', 'tex', ...
          'DefaultLegendInterpreter', 'tex');

colorVin       = [0.12 0.45 0.82];  % Royal Blue
colorSchmitt   = [0.85 0.22 0.18];  % Crimson / Coral Red
colorVth       = [0.88 0.42 0.08];  % Amber / Orange
colorVtl       = [0.15 0.62 0.32];  % Emerald Green
colorBand      = [0.93 0.93 0.96];  % Light Lavender Gray
colorActMarker = [0.08 0.58 0.25];  % Deep Green (Activation)
colorDeMarker  = [0.85 0.18 0.18];  % Vivid Red (Deactivation)

% Top panel: Analog Input Voltage Vin(t)
% Left margin 0.12, width 0.84 to utilize full canvas width cleanly
ax1 = axes('Parent', fig1, 'Position', [0.12 0.55 0.84 0.38]);
hold(ax1, 'on');
set(ax1, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.22, 'LineWidth', 1.0);
grid(ax1, 'on');

% Primary input voltage curve
h_vin = plot(ax1, t_in, v_in, '-', 'Color', colorVin, 'LineWidth', 1.8, ...
    'DisplayName', 'Analog Input Voltage V_{in}(t) [Potentiometer]');

% Optional threshold lines & hysteresis band
topHandles = h_vin;
if SHOW_THRESHOLDS
    t_span = [0 totalDuration totalDuration 0];
    y_band = [circuit.Vtl_theo circuit.Vtl_theo circuit.Vth_theo circuit.Vth_theo];
    h_band = patch(ax1, t_span, y_band, colorBand, 'EdgeColor', 'none', ...
        'FaceAlpha', 0.60, 'DisplayName', sprintf('Hysteresis Band \\DeltaV_H = %.1f mV', circuit.Vh_theo*1e3));
    h_vth = yline(ax1, circuit.Vth_theo, '--', 'Color', colorVth, 'LineWidth', 1.6, ...
        'DisplayName', sprintf('Upper Threshold V_{TH} = %.3f V', circuit.Vth_theo));
    h_vtl = yline(ax1, circuit.Vtl_theo, '-.', 'Color', colorVtl, 'LineWidth', 1.6, ...
        'DisplayName', sprintf('Lower Threshold V_{TL} = %.3f V', circuit.Vtl_theo));
    topHandles = [topHandles; h_vth; h_vtl; h_band];
end

% Optional activation/deactivation event markers
if SHOW_ACTIVATION
    h_act = scatter(ax1, t_rising, vin_at_rising, 70, '^', 'filled', ...
        'MarkerFaceColor', colorActMarker, 'MarkerEdgeColor', [0.05 0.35 0.12], ...
        'LineWidth', 1.1, 'DisplayName', 'Trigger Activated (LOW \rightarrow HIGH)');
    h_deact = scatter(ax1, t_falling, vin_at_falling, 70, 'v', 'filled', ...
        'MarkerFaceColor', colorDeMarker, 'MarkerEdgeColor', [0.50 0.05 0.05], ...
        'LineWidth', 1.1, 'DisplayName', 'Trigger Deactivated (HIGH \rightarrow LOW)');
    topHandles = [topHandles; h_act; h_deact];
end

ylabel(ax1, 'Input Voltage V_{in} (V)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax1, 'Real-Time Potentiometer Signal & Schmitt Trigger Response', ...
    'FontSize', 13, 'FontWeight', 'bold');
xlim(ax1, [0 totalDuration]);
% Set generous headroom up to 4.4V so legend box sits strictly above all signal peaks (3.3V max)
ylim(ax1, [-0.2 4.4]);
yticks(ax1, 0:0.5:4.0);

% Legend box positioned with clear separation from signal curves
legend(ax1, topHandles, 'Location', 'northwest', 'FontSize', 10, ...
    'Box', 'on', 'Color', [1 1 1], 'EdgeColor', [0.75 0.75 0.75]);

% Bottom panel: Schmitt Trigger Output Vout(t)
ax2 = axes('Parent', fig1, 'Position', [0.12 0.10 0.84 0.38]);
hold(ax2, 'on');
set(ax2, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.22, 'LineWidth', 1.0);
grid(ax2, 'on');

% Optional shaded fill under active trigger
bottomHandles = [];
if SHOW_PULSE_SHADING
    h_pulse = area(ax2, t_sch, v_sch, 'BaseValue', 0, ...
        'FaceColor', colorSchmitt, 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
        'DisplayName', 'Active Trigger State (V_{out} = 3.30 V)');
    bottomHandles = [bottomHandles; h_pulse];
end

% Schmitt trigger digital bi-stable switching trace
h_vout = plot(ax2, t_sch, v_sch, '-', 'Color', colorSchmitt, 'LineWidth', 2.0, ...
    'DisplayName', 'Schmitt Output V_{out}(t)');
bottomHandles = [h_vout; bottomHandles];

% Subtle mid-supply reference indicator
yline(ax2, v_mid, ':', 'Color', [0.55 0.55 0.60], 'LineWidth', 1.0, ...
    'HandleVisibility', 'off');

xlabel(ax2, timeAxisLabel, 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax2, 'Schmitt Output V_{out} (V)', 'FontSize', 12, 'FontWeight', 'bold');
title(ax2, 'Schmitt Trigger Digital Response (Non-Inverting Bi-Stable Switching)', ...
    'FontSize', 12.5, 'FontWeight', 'bold');
xlim(ax2, [0 totalDuration]);
% Set generous headroom up to 4.4V so legend box sits strictly above 3.3V pulse level
ylim(ax2, [-0.3 4.4]);
yticks(ax2, [0, 1.65, 3.3]);
yticklabels(ax2, {'0.0 V (LOW)', '1.65 V (Mid)', '3.3 V (HIGH)'});

% Legend box positioned with clear separation from digital pulse lines
legend(ax2, bottomHandles, 'Location', 'northwest', 'FontSize', 10, ...
    'Box', 'on', 'Color', [1 1 1], 'EdgeColor', [0.75 0.75 0.75]);

linkaxes([ax1, ax2], 'x');

% Optional right sidebar card (disabled by default per user specification)
if SHOW_SIDEBAR_CARD
    annotText = sprintf(['\\bfSimscape Circuit Model\\rm\n', ...
        '\\bullet Schematic: sensorExpoler\\_poten\n', ...
        '\\bullet Topology: Non-Inverting Schmitt\n', ...
        '\\bullet R_{in} = 3.9 k\\Omega,  R_h = 576 k\\Omega\n', ...
        '\\bullet R_x = R_y = 10 k\\Omega \\rightarrow V_{ref} = 1.650 V\n', ...
        '\\bullet V_{OS} = 5.0 mV (Offset)\n\n', ...
        '\\bfTheoretical Thresholds:\\rm\n', ...
        '\\bullet V_{TH} = 1.666 V (1666.2 mV)\n', ...
        '\\bullet V_{TL} = 1.644 V (1643.9 mV)\n', ...
        '\\bullet \\DeltaV_H = 22.3 mV (Hysteresis)\n\n', ...
        '\\bfActive Sweep Metrics (Trimmed):\\rm\n', ...
        '\\bullet Window: [%.1f s, %.1f s]\n', ...
        '\\bullet V_{TH, mean} = %.3f \\pm %.3f V\n', ...
        '\\bullet V_{TL, mean} = %.3f \\pm %.3f V\n', ...
        '\\bullet \\DeltaV_{H, mean} = %.1f mV\n', ...
        '\\bullet Active Cycles: %d Complete\n', ...
        '\\bullet Transitions: %d Total\n', ...
        '\\bullet Noise Margin: \\pm%.1f mV around V_{ref}'], ...
        TRIM_START_TIME, TRIM_END_TIME, ...
        vth_meas_mean, vth_meas_std, vtl_meas_mean, vtl_meas_std, ...
        vh_meas*1e3, nCycles, nTransitions, (circuit.Vh_theo/2)*1e3);

    annotation(fig1, 'textbox', [0.79 0.12 0.19 0.81], 'String', annotText, ...
        'FitBoxToText', 'off', 'BackgroundColor', [0.98 0.98 0.99], ...
        'EdgeColor', [0.72 0.72 0.75], 'FontSize', 9.0, 'Margin', 6);
end

drawnow;

% Export Figure 1
outPng1 = fullfile(figDir, 'schmitt_trigger_time_domain.png');
outFig1 = fullfile(figDir, 'schmitt_trigger_time_domain.fig');
exportgraphics(fig1, outPng1, 'Resolution', 600);
savefig(fig1, outFig1);
copyfile(outPng1, fullfile(repDir, 'schmitt_trigger_time_domain.png'));
fprintf('Saved Figure 1 to:\n  - %s\n  - %s\n', outPng1, outFig1);

%% 6. FIGURE 2: Transfer Characteristic & Zoomed Hysteresis Loop
vin_interp = interp1(t_in, v_in, t_sch, 'linear', 'extrap');

fig2 = figure('Color', 'w', 'Position', [90 90 1060 560], ...
    'Name', 'Schmitt Trigger Transfer Characteristic & Hysteresis Analysis (Active Sweeps)');
set(fig2, 'DefaultTextInterpreter', 'tex', ...
          'DefaultAxesTickLabelInterpreter', 'tex', ...
          'DefaultLegendInterpreter', 'tex');

dvin_dt = [0; diff(vin_interp)] ./ [1; diff(t_sch)];
smooth_dvin = movmean(dvin_dt, 100);
idx_rise = smooth_dvin > 0.05;
idx_fall = smooth_dvin < -0.05;

% Subplot A: Full-Range Transfer Curve (0 to 3.3V)
ax2A = subplot(1, 2, 1);
hold(ax2A, 'on');
set(ax2A, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.22, 'LineWidth', 1.0);
grid(ax2A, 'on');

v_low_x  = [0, circuit.Vth_theo, circuit.Vth_theo];
v_low_y  = [0, 0, circuit.Voh];
v_high_x = [3.3, circuit.Vtl_theo, circuit.Vtl_theo];
v_high_y = [circuit.Voh, circuit.Voh, 0];

h_theoA = plot(ax2A, [v_low_x, NaN, v_high_x], [v_low_y, NaN, v_high_y], ...
    'k--', 'LineWidth', 2.0, 'DisplayName', 'Theoretical Model');

h_measA_rise = plot(ax2A, vin_interp(idx_rise), v_sch(idx_rise), '.', ...
    'Color', [0.15 0.55 0.90], 'MarkerSize', 4.5, ...
    'DisplayName', 'Measured: Forward / Rising (dV_{in}/dt > 0)');

h_measA_fall = plot(ax2A, vin_interp(idx_fall), v_sch(idx_fall), '.', ...
    'Color', [0.90 0.25 0.20], 'MarkerSize', 4.5, ...
    'DisplayName', 'Measured: Reverse / Falling (dV_{in}/dt < 0)');

xline(ax2A, circuit.Vth_theo, ':', 'Color', colorVth, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('V_{TH} = %.3f V', circuit.Vth_theo));
xline(ax2A, circuit.Vtl_theo, ':', 'Color', colorVtl, 'LineWidth', 1.4, ...
    'DisplayName', sprintf('V_{TL} = %.3f V', circuit.Vtl_theo));

xlabel(ax2A, 'Analog Input Voltage V_{in} (V) \rightarrow', 'FontSize', 11.5, 'FontWeight', 'bold');
ylabel(ax2A, 'Schmitt Output V_{out} (V) \rightarrow', 'FontSize', 11.5, 'FontWeight', 'bold');
title(ax2A, 'Full-Scale Transfer Characteristic (0 - 3.3 V)', 'FontSize', 12, 'FontWeight', 'bold');
xlim(ax2A, [-0.1 3.4]);
ylim(ax2A, [-0.2 3.6]);
xticks(ax2A, 0:0.5:3.3);
yticks(ax2A, [0, 1.65, 3.3]);
yticklabels(ax2A, {'0.0 V (V_{OL})', '1.65 V', '3.3 V (V_{OH})'});
legend(ax2A, 'Location', 'northwest', 'FontSize', 8.5, 'Box', 'on');

% Subplot B: Zoomed-in Hysteresis Loop around Trip Points (1.58 - 1.76 V)
ax2B = subplot(1, 2, 2);
hold(ax2B, 'on');
set(ax2B, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.22, 'LineWidth', 1.0);
grid(ax2B, 'on');

patch(ax2B, [circuit.Vtl_theo circuit.Vth_theo circuit.Vth_theo circuit.Vtl_theo], ...
    [-0.2 -0.2 3.5 3.5], [0.93 0.93 0.97], 'EdgeColor', 'none', ...
    'FaceAlpha', 0.75, 'DisplayName', sprintf('Hysteresis Band \\DeltaV_H = %.1f mV', circuit.Vh_theo*1e3));

plot(ax2B, [v_low_x, NaN, v_high_x], [v_low_y, NaN, v_high_y], ...
    'k--', 'LineWidth', 2.2, 'DisplayName', 'Theoretical Model');

plot(ax2B, vin_interp(idx_rise), v_sch(idx_rise), '.', ...
    'Color', [0.15 0.55 0.90], 'MarkerSize', 6.0, ...
    'DisplayName', 'Measured: Rising (dV_{in}/dt > 0)');
plot(ax2B, vin_interp(idx_fall), v_sch(idx_fall), '.', ...
    'Color', [0.90 0.25 0.20], 'MarkerSize', 6.0, ...
    'DisplayName', 'Measured: Falling (dV_{in}/dt < 0)');

xline(ax2B, circuit.Vth_theo, '--', 'Color', colorVth, 'LineWidth', 1.8, ...
    'DisplayName', sprintf('V_{TH} = %.3f V', circuit.Vth_theo));
xline(ax2B, circuit.Vtl_theo, '-.', 'Color', colorVtl, 'LineWidth', 1.8, ...
    'DisplayName', sprintf('V_{TL} = %.3f V', circuit.Vtl_theo));

text(ax2B, circuit.Vth_theo + 0.005, 1.85, '\bf\rightarrow Turn ON (Rising)\rm', ...
    'Color', [0.10 0.45 0.80], 'FontSize', 10, 'FontWeight', 'bold');
text(ax2B, circuit.Vtl_theo - 0.045, 1.45, '\bf\leftarrow Turn OFF (Falling)\rm', ...
    'Color', [0.85 0.20 0.15], 'FontSize', 10, 'FontWeight', 'bold');

xlabel(ax2B, 'Analog Input Voltage V_{in} (V) [Zoomed] \rightarrow', 'FontSize', 11.5, 'FontWeight', 'bold');
ylabel(ax2B, 'Schmitt Output V_{out} (V) \rightarrow', 'FontSize', 11.5, 'FontWeight', 'bold');
title(ax2B, 'Zoomed Hysteresis Loop & Threshold Band (\DeltaV_H)', 'FontSize', 12, 'FontWeight', 'bold');
xlim(ax2B, [1.58 1.76]);
ylim(ax2B, [-0.2 3.6]);
xticks(ax2B, 1.58:0.04:1.76);
yticks(ax2B, [0, 1.65, 3.3]);
yticklabels(ax2B, {'0.0 V (LOW)', '1.65 V', '3.3 V (HIGH)'});
legend(ax2B, 'Location', 'northwest', 'FontSize', 8.5, 'Box', 'on');

drawnow;

% Export Figure 2
outPng2 = fullfile(figDir, 'schmitt_trigger_hysteresis.png');
outFig2 = fullfile(figDir, 'schmitt_trigger_hysteresis.fig');
exportgraphics(fig2, outPng2, 'Resolution', 600);
savefig(fig2, outFig2);
copyfile(outPng2, fullfile(repDir, 'schmitt_trigger_hysteresis.png'));
fprintf('Saved Figure 2 to:\n  - %s\n  - %s\n', outPng2, outFig2);

%% 7. Optional Interactive Real-Time Playback Oscilloscope
if ENABLE_ANIMATION
    fprintf('\nLaunching Interactive Real-Time Oscilloscope Playback (Speed = %.1fx)...\n', PLAYBACK_SPEED);
    fig3 = figure('Color', 'w', 'Position', [140 140 920 620], ...
        'Name', 'Live Oscilloscope: Real-Time Signal & Schmitt Trigger Activation');
    set(fig3, 'DefaultTextInterpreter', 'tex', ...
              'DefaultAxesTickLabelInterpreter', 'tex', ...
              'DefaultLegendInterpreter', 'tex');
    
    axLive1 = subplot(2, 1, 1);
    hold(axLive1, 'on');
    grid(axLive1, 'on');
    set(axLive1, 'FontSize', 10.5, 'Box', 'on', 'XLim', [0 15], 'YLim', [-0.2 3.6]);
    title(axLive1, 'LIVE ANALOG INPUT SIGNAL V_{in}(t) [POTENTIOMETER]', 'FontWeight', 'bold');
    ylabel(axLive1, 'Voltage (V)', 'FontWeight', 'bold');
    yline(axLive1, circuit.Vth_theo, '--', 'Color', colorVth, 'LineWidth', 1.4);
    yline(axLive1, circuit.Vtl_theo, '-.', 'Color', colorVtl, 'LineWidth', 1.4);
    lineLiveVin = animatedline(axLive1, 'Color', colorVin, 'LineWidth', 2.0);
    markerCurrentVin = plot(axLive1, 0, 0, 'o', 'MarkerSize', 8, ...
        'MarkerFaceColor', colorVin, 'MarkerEdgeColor', 'k');
    
    axLive2 = subplot(2, 1, 2);
    hold(axLive2, 'on');
    grid(axLive2, 'on');
    set(axLive2, 'FontSize', 10.5, 'Box', 'on', 'XLim', [0 15], 'YLim', [-0.3 3.6]);
    title(axLive2, 'LIVE SCHMITT TRIGGER OUTPUT V_{out}(t)', 'FontWeight', 'bold');
    xlabel(axLive2, timeAxisLabel, 'FontWeight', 'bold');
    ylabel(axLive2, 'Output (V)', 'FontWeight', 'bold');
    yticks(axLive2, [0, 3.3]);
    yticklabels(axLive2, {'0 V (OFF)', '3.3 V (ON)'});
    lineLiveVsch = animatedline(axLive2, 'Color', colorSchmitt, 'LineWidth', 2.2);
    markerCurrentVsch = plot(axLive2, 0, 0, 's', 'MarkerSize', 8, ...
        'MarkerFaceColor', colorSchmitt, 'MarkerEdgeColor', 'k');
    
    hudText = annotation(fig3, 'textbox', [0.72 0.78 0.22 0.14], ...
        'String', sprintf('\\bfLIVE STATUS\\rm\nTime: 0.00 s\nV_{in}: 0.000 V\nState: \\bfINACTIVE\\rm'), ...
        'BackgroundColor', [0.95 0.95 0.95], 'EdgeColor', [0.6 0.6 0.6], 'FontSize', 9.5);
    
    frameDtSim = 0.033 * PLAYBACK_SPEED;
    windowWidth = 15.0;
    t_curr = 0;
    stepIdx = 1;
    
    while t_curr < totalDuration && ishandle(fig3)
        t_curr = t_curr + frameDtSim;
        targetIdx = find(t_sch >= t_curr, 1);
        if isempty(targetIdx), break; end
        
        chunkT   = t_sch(stepIdx:targetIdx);
        chunkVin = vin_interp(stepIdx:targetIdx);
        chunkSch = v_sch(stepIdx:targetIdx);
        
        addpoints(lineLiveVin, chunkT, chunkVin);
        addpoints(lineLiveVsch, chunkT, chunkSch);
        
        curVin  = chunkVin(end);
        curVsch = chunkSch(end);
        
        set(markerCurrentVin, 'XData', chunkT(end), 'YData', curVin);
        set(markerCurrentVsch, 'XData', chunkT(end), 'YData', curVsch);
        
        if t_curr > windowWidth
            set(axLive1, 'XLim', [t_curr - windowWidth, t_curr + 1]);
            set(axLive2, 'XLim', [t_curr - windowWidth, t_curr + 1]);
        end
        
        if curVsch > v_mid
            stateStr = '\bf\color[rgb]{0.1,0.6,0.2}ACTIVE (ON)\rm';
        else
            stateStr = '\bf\color[rgb]{0.5,0.5,0.5}INACTIVE (OFF)\rm';
        end
        set(hudText, 'String', sprintf(['\\bfLIVE STATUS\\rm\n', ...
            'Time: %.2f s\n', ...
            'V_{in}: %.3f V\n', ...
            'State: %s'], t_curr, curVin, stateStr));
        
        drawnow limitrate;
        stepIdx = targetIdx + 1;
        pause(0.025);
    end
    fprintf('Interactive Oscilloscope Playback finished.\n');
else
    fprintf('Note: Interactive animation is currently toggled OFF for batch script execution.\n');
    fprintf('      To view the live animated playback, set ENABLE_ANIMATION = true;\n');
    fprintf('      at the top of %s.\n\n', mfilename);
end

fprintf('========================================================================\n');
fprintf(' SCHMITT TRIGGER ANALYSIS COMPLETED SUCCESSFULLY\n');
fprintf(' All outputs generated in Figures/Schmitt Trigger/ and Results/\n');
fprintf('========================================================================\n');

%% --- Helper Function ---
function [t, y] = extractTimeSeries(elem)
    if isa(elem, 'Simulink.SimulationData.Signal')
        val = elem.Values;
    else
        val = elem;
    end
    
    if isa(val, 'timeseries')
        t = val.Time;
        y = val.Data;
    elseif isa(val, 'timetable')
        t = seconds(val.Time);
        y = val{:, 1};
    elseif isstruct(val) && isfield(val, 'time') && isfield(val, 'signals')
        t = val.time;
        y = val.signals.values;
    else
        error('Unsupported signal format for element.');
    end
end
