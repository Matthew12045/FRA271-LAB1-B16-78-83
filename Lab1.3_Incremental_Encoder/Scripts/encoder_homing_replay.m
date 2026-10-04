%% ENCODER_HOMING_REPLAY Replay recorded raw counts through the encoder models with Home presses.
%  For each model (AMT103-V, Bourns) a copy is made in a temporary folder, Host Serial Rx is
%  replaced by From Workspace blocks carrying the recorded raw EncoderX4 of the wrap-around run
%  (Data/เพิ่มเติม/AMT_wraparound.mat, Bourns_wraparoundmat.mat), and the 'home' Constant (held to 1
%  by the Dashboard Home Button on the rig) is replaced by a 0.3 s pulse at chosen times: AMT103-V one
%  press at rest and one while turning, Bourns one press while turning. The copy is simulated; the saved models are
%  not changed. Logged: pulses X4, pos_home X4, theta_home_deg X4, is_homed, homing_state.
%  Writes Results/encoder_homing_replay.csv.
%
% Compatible with MATLAB R2023a through R2026a (needs the Waijung library on the path to load the model).

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
dataDir = fullfile(rootDir, 'Data', 'เพิ่มเติม');
figDir  = fullfile(rootDir, 'Figures');
repDir  = fullfile(rootDir, 'Results');
U = encoder_report_style();
PRESS = 0.3;   % s, how long Home is held

cfg = struct( ...
    'name',  {'AMT103-V', 'Bourns PEC11R'}, ...
    'model', {'sensorExpoler_Encoder_AMT_103V', 'sensorExpoler_Encoder_Bourns'}, ...
    'file',  {'AMT_wraparound.mat', 'Bourns_wraparoundmat.mat'}, ...
    'press', {[2.0 9.5], 13.12}, ...
    'cpr',   {8192, 96}, ...
    'out',   {'homing_amt', 'homing_bourns'});

workDir = fullfile(tempdir, 'encoder_homing_replay');
if ~exist(workDir, 'dir'), mkdir(workDir); end
addpath(workDir);
fileGen = Simulink.fileGenControl('getConfig');
Simulink.fileGenControl('set', 'CacheFolder', workDir, 'CodeGenFolder', workDir);   % keep .slxc/slprj out of the repo
cleanupObj = onCleanup(@() restore(workDir, fileGen));

events = table();
for e = 1:2
    [raw, t] = load_encoder_signal(fullfile(dataDir, cfg(e).file), 'EncoderX4');
    home = zeros(size(t));
    for tp = cfg(e).press
        home(t >= tp & t < tp + PRESS) = 1;
    end

    mdl = sprintf('homing_replay_%d', e);
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    copyfile(fullfile(rootDir, 'Simulink', [cfg(e).model '.slx']), fullfile(workDir, [mdl '.slx']), 'f');
    load_system(fullfile(workDir, [mdl '.slx']));
    swap_sources(mdl);
    set_param(mdl, 'StopTime', num2str(t(end)), 'FixedStep', '1e-3', 'SignalLogging', 'on', ...
        'UnconnectedInputMsg', 'none', 'UnconnectedOutputMsg', 'none', 'UnconnectedLineMsg', 'none');

    simIn = Simulink.SimulationInput(mdl);
    simIn = simIn.setVariable('rawX4', timeseries(uint32(raw), t));
    simIn = simIn.setVariable('homeSig', timeseries(home, t));
    out = sim(simIn);
    logs = out.get(get_param(mdl, 'SignalLoggingName'));
    close_system(mdl, 0);

    [p, tp] = logged(logs, 'pulses X4');
    ph = logged(logs, 'pos_home X4');
    thh = logged(logs, 'theta_home_deg X4');
    st = logged(logs, 'homing_state');
    ok = logged(logs, 'is_homed');
    fprintf('%s: is_homed equals (homing_state == 2) at every sample: %d\n', cfg(e).name, isequal(ok ~= 0, st == 2));

    fig = U.figure(cfg(e).name, 480);
    fig.Position(3) = 620;                    % narrow canvas: legible text at half a page wide
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl);
    U.axes(ax1);
    hP = plot(ax1, tp, p * 360 / cfg(e).cpr, '-', 'Color', U.grey, 'LineWidth', 2.4, 'DisplayName', 'Before homing');
    hH = plot(ax1, tp, thh, '-', 'Color', U.mode(3, :), 'LineWidth', 1.6, 'DisplayName', 'After homing');
    for k = 1:numel(cfg(e).press)
        i0 = find(tp >= cfg(e).press(k), 1);
        i1 = find(st(i0:end) == 2, 1) + i0 - 1;
        xline(ax1, tp(i0), '--', 'Color', U.mode(2, :), 'LineWidth', 1.2, 'HandleVisibility', 'off');
        plot(ax1, tp(i1), thh(i1), 'o', 'Color', U.ink, 'MarkerFaceColor', U.mode(2, :), 'MarkerSize', 7, 'HandleVisibility', 'off');
        events = [events; table(string(cfg(e).name), k, tp(i0), tp(i1), tp(i1) - tp(i0), p(i0), p(i1), ...
            p(i1) * 360 / cfg(e).cpr, ph(i1), ...
            'VariableNames', {'Encoder', 'Press', 'PressTime_s', 'HomedTime_s', 'Wait_s', 'PulsesAtPress', ...
                              'OffsetPulses', 'OffsetDeg', 'PosHomeAtHomed'})]; %#ok<AGROW>
    end
    yAll = [p * 360 / cfg(e).cpr; thh];
    pad = 0.08 * max(max(yAll) - min(yAll), 1);
    ylim(ax1, [min(yAll) - pad, max(yAll) + pad]);   % keep the 0 deg line off the frame
    ylabel(ax1, 'Angle (deg)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax1, '(a) Angle (Count2Deg) before and after homing', 'FontSize', 12, 'FontWeight', 'bold');

    ax2 = nexttile(tl);
    U.axes(ax2);
    hB = stairs(ax2, t, home * 2.2, '-', 'Color', U.mode(2, :), 'LineWidth', 1.4, 'DisplayName', 'Home button');
    hS = stairs(ax2, tp, st, '-', 'Color', U.mode(1, :), 'LineWidth', 2.0, 'DisplayName', 'homing\_state');
    yticks(ax2, [0 1 2]);
    yticklabels(ax2, {'0', '1 wait', '2 homed'});
    ylim(ax2, [-0.3 2.6]);
    xlabel(ax2, 'Time (s)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax2, '(b) Home button and homing state', 'FontSize', 12, 'FontWeight', 'bold');
    % one legend below the figure; press and homed times are in the report text and the CSV
    dP = plot(ax2, NaN, NaN, '-', 'Color', U.grey, 'LineWidth', 2.4, 'DisplayName', hP.DisplayName);
    dH = plot(ax2, NaN, NaN, '-', 'Color', U.mode(3, :), 'LineWidth', 1.6, 'DisplayName', hH.DisplayName);
    legend(ax2, [dP dH hB hS], 'Location', 'southoutside', 'NumColumns', 4, 'FontSize', 10.5, 'Box', 'off');
    linkaxes([ax1 ax2], 'x');
    xlim(ax2, [0 t(end)]);
    U.save(fig, fullfile(figDir, cfg(e).out));
end
disp(events);
writetable(events, fullfile(repDir, 'encoder_homing_replay.csv'));
fprintf('Saved %s\n', fullfile(repDir, 'encoder_homing_replay.csv'));

%% ---------------------------------------------------------------- helpers
function swap_sources(mdl)
% Host Serial Rx -> From Workspace on the X4 input; home Constant -> From Workspace.
delete_block(find_system(mdl, 'SearchDepth', 1, 'BlockType', 'PushButtonBlock'));
pos = get_param([mdl '/Host Serial Rx'], 'Position');
hp = get_param([mdl '/home'], 'Position');
delete_block([mdl '/Host Serial Rx']);
delete_block([mdl '/Host Serial Setup']);
delete_block([mdl '/home']);
delete_line(find_system(mdl, 'FindAll', 'on', 'Type', 'line', 'Connected', 'off'));
add_block('simulink/Sources/From Workspace', [mdl '/rawX4'], 'Position', [pos(1) pos(2) pos(1) + 120 pos(2) + 40], ...
    'VariableName', 'rawX4', 'SampleTime', '1e-3', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_block('simulink/Sources/From Workspace', [mdl '/homeSrc'], 'Position', hp + [-60 0 0 0], ...
    'VariableName', 'homeSig', 'SampleTime', '1e-3', 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
add_line(mdl, 'rawX4/1', 'WrapAround2/1', 'autorouting', 'smart');
add_line(mdl, 'homeSrc/1', 'HomingSequence/2', 'autorouting', 'smart');
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
