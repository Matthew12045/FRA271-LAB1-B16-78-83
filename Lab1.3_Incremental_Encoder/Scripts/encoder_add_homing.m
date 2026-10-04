%% ENCODER_ADD_HOMING Add the Homing Sequence to the X4 path of both encoder models.
%  Adds to sensorExpoler_Encoder_AMT_103V.slx and sensorExpoler_Encoder_Bourns.slx:
%    home            Constant 0, set to 1 while the Dashboard 'Home Button' is held (momentary)
%    HomingSequence  MATLAB Function with the code of HomingSequence.m, input = X4 WrapAround output
%    Count2Deg_home  copy of Count2Deg2 (same PPR2 / MULT2) for the homed angle in degrees
%    four Displays, and logged signals 'pos_home X4', 'theta_home_deg X4', 'is_homed', 'homing_state'
%  The blocks sit below the X4 velocity subsystem. Running the script again only refreshes the
%  MATLAB Function code from HomingSequence.m.
%
% Compatible with MATLAB R2023a through R2026a (Dashboard Push Button block).

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
simDir = fullfile(fileparts(thisDir), 'Simulink');
code = fileread(fullfile(thisDir, 'HomingSequence.m'));

for f = {'sensorExpoler_Encoder_AMT_103V', 'sensorExpoler_Encoder_Bourns'}
    m = f{1};
    load_system(fullfile(simDir, [m '.slx']));
    blk = [m '/HomingSequence'];
    isNew = getSimulinkBlockHandle(blk) == -1;
    if isNew
        add_block('simulink/User-Defined Functions/MATLAB Function', blk, 'Position', [1120 2160 1270 2250]);
    end
    chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', blk);
    chart.Script = code;
    if isNew
        add_homing_blocks(m);
    end
    save_system(m);
    close_system(m);
    if isNew
        fprintf('%s: HomingSequence added\n', m);
    else
        fprintf('%s: HomingSequence code refreshed\n', m);
    end
end

%% ---------------------------------------------------------------- helpers
function add_homing_blocks(m)
add_block('simulink/Sources/Constant', [m '/home'], 'Value', '0', 'Position', [835 2190 895 2220]);
add_block([m '/Reset Button'], [m '/Home Button'], 'Position', [819 2130 910 2174], 'ButtonText', 'Home');
b = get_param([m '/Reset Button'], 'Binding');
b.BlockPath = Simulink.BlockPath([m '/home']);
set_param([m '/Home Button'], 'Binding', b);

add_block([m '/Count2Deg2'], [m '/Count2Deg_home'], 'Position', [1350 2160 1455 2230]);
shown = {'Display_pos_home X4', [1550 2150 1630 2190]
        'Display_theta_home X4', [1550 2205 1630 2245]
        'Display_is_homed', [1550 2260 1630 2300]
        'Display_homing_state', [1550 2315 1630 2355]};
for k = 1:size(shown, 1)
    add_block('simulink/Sinks/Display', [m '/' shown{k, 1}], 'Position', shown{k, 2});
end

connect(m, 'WrapAround2/1', 'HomingSequence/1', '');
connect(m, 'home/1', 'HomingSequence/2', '');
connect(m, 'HomingSequence/1', 'Count2Deg_home/1', 'pos_home X4');
connect(m, 'HomingSequence/1', 'Display_pos_home X4/1', '');
connect(m, 'PPR2/1', 'Count2Deg_home/2', '');
connect(m, 'MULT2/1', 'Count2Deg_home/3', '');
connect(m, 'Count2Deg_home/1', 'Display_theta_home X4/1', 'theta_home_deg X4');
connect(m, 'HomingSequence/2', 'Display_is_homed/1', 'is_homed');
connect(m, 'HomingSequence/3', 'Display_homing_state/1', 'homing_state');
end

function connect(m, from, to, name)
% Add a line; a non-empty name labels the source port's line and turns on its logging.
h = add_line(m, from, to, 'autorouting', 'smart');
if ~isempty(name)
    set_param(h, 'Name', name);
    set_param(get_param(h, 'SrcPortHandle'), 'DataLogging', 'on');
end
end
