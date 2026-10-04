%% LC_BUILD_MODEL Build sensorExpoler_loadcell.slx, the real-time weight model of Lab 1.4.
%  Starts from the course model used in Lab 1.2 (Host Serial Rx -> A0 / 4095 * 3300 -> voltage(mV)
%  -> Moving Average, 512 samples) and replaces the MATLAB Function with calc_Weight, which turns
%  the filtered voltage into weight in newtons (SI derived unit) and mass in kg using the
%  calibration from lc_calibration.m:
%     A0 -> V = A0 / 4095 * 3300 [mV] -> moving average (512 samples, 0.512 s)
%        -> m = (V - V0) / S [kg],  F = m * g [N]
%  Logged signals: A0, voltage(mV), filtered voltage(mV), weight(N), mass(kg).
%
% Compatible with MATLAB R2020a through R2026a (needs the Waijung aMG USB Converter library and
% the DSP System Toolbox for the Moving Average block).

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
repDir  = fullfile(rootDir, 'Results');
src     = fullfile(fileparts(rootDir), 'Lab1.2_Magnetic_Sensor', 'Simulink', 'sensorExpoler_magnetic.slx');
mdl     = 'sensorExpoler_loadcell';
dst     = fullfile(rootDir, 'Simulink', [mdl '.slx']);

L = load(fullfile(repDir, 'lc_calibration.mat'));
S_mV = round(L.cal.S * 1000, 2);    % mV/kg
V0_mV = round(L.cal.V0 * 1000, 2);  % mV

if bdIsLoaded(mdl), close_system(mdl, 0); end
copyfile(src, dst, 'f');
fileattrib(dst, '+w');
load_system(dst);

%% calc_Weight
blk = [mdl '/calc_Weight'];
set_param([mdl '/MATLAB Function'], 'Name', 'calc_Weight');
chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', blk);
chart.Script = sprintf([ ...
    'function [F, m] = calc_Weight(V)\n', ...
    '    %% YZC-131A + INA125 (G = 476, RG = 127 ohm), calibrated with runs 1-3\n', ...
    '    S  = %.2f;    %% sensitivity in mV/kg\n', ...
    '    V0 = %.2f;    %% output voltage at zero load in mV\n', ...
    '    g  = 9.81;      %% gravitational acceleration in m/s^2\n', ...
    '\n', ...
    '    m = (V - V0) / S;   %% mass in kg\n', ...
    '    F = m * g;          %% weight in N (SI derived unit)\n', ...
    'end'], S_mV, V0_mV);

%% Re-wire Multiply -> Moving Average -> calc_Weight -> displays
ports = [port_list([mdl '/Multiply'], {'Outport'}), port_list([mdl '/Moving Average'], {'Inport', 'Outport'}), ...
         port_list(blk, {'Inport', 'Outport'})];
for h = ports
    ln = get_param(h, 'Line');
    if ln > 0, delete_line(ln); end
end
set_param([mdl '/Multiply'],       'Position', [1035 315 1065 345]);
set_param([mdl '/Moving Average'], 'Position', [1170 305 1240 355]);
set_param(blk,                     'Position', [1380 300 1490 360]);
set_param([mdl '/Display8'],       'Position', [1170 215 1260 245]);
set_param([mdl '/Display10'],      'Position', [1380 215 1470 245]);
set_param([mdl '/Display9'],       'Position', [1600 285 1690 315]);
add_block('simulink/Sinks/Display', [mdl '/Display11'], 'Position', [1600 350 1690 380]);

l1 = add_line(mdl, 'Multiply/1', 'Moving Average/1', 'autorouting', 'smart');
add_line(mdl, 'Multiply/1', 'Display8/1', 'autorouting', 'smart');
l2 = add_line(mdl, 'Moving Average/1', 'calc_Weight/1', 'autorouting', 'smart');
add_line(mdl, 'Moving Average/1', 'Display10/1', 'autorouting', 'smart');
l3 = add_line(mdl, 'calc_Weight/1', 'Display9/1', 'autorouting', 'smart');
l4 = add_line(mdl, 'calc_Weight/2', 'Display11/1', 'autorouting', 'smart');
names = {'voltage(mV)', 'filtered voltage(mV)', 'weight(N)', 'mass(kg)'};
lines = [l1 l2 l3 l4];
for k = 1:4
    set_param(lines(k), 'Name', names{k});
    set_param(get_param(lines(k), 'SrcPortHandle'), 'DataLogging', 'on', 'DataLoggingNameMode', 'SignalName');
end
set_param(mdl, 'StopTime', '10');

save_system(mdl, dst);
close_system(mdl, 0);
fprintf('Saved %s (S = %.2f mV/kg, V0 = %.2f mV)\n', dst, S_mV, V0_mV);

%% ---------------------------------------------------------------- helpers
function h = port_list(block, fields)
% Port handles of the listed kinds ('Inport', 'Outport') of a block, as one row.
ph = get_param(block, 'PortHandles');
h = [];
for f = fields
    h = [h ph.(f{1})(:)']; %#ok<AGROW>
end
end
