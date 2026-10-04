%% ENCODER_EXPORT_MODEL Export the encoder Simulink model and its MATLAB Function code as report figures.
%  1) Top-level block diagram of sensorExpoler_Encoder_AMT_103V.slx (Host Serial Rx -> WrapAround ->
%     Count2Deg / Count2Rad -> Angle_to_AngularVelocity, plus the X4 Homing Sequence), and a report
%     view of the X4 path only: a temporary copy keeps the X4 and homing blocks and is auto-arranged
%     (the X1 and X2 paths are the same blocks with MULT = 1 and 2).
%  2) Editor-style listings of the code inside the MATLAB Function blocks, read from the model itself:
%     WrapAround2, Count2Rad2 + Count2Deg2, HomingSequence, Angle_to_AngularVelocity_X4/FilteredAngularVelocity.
%     A listing can be limited to a line range (an excerpt keeps the original line numbers).
%  The model is loaded without opening a window and is never saved.
%
% Compatible with MATLAB R2020a through R2026a (needs the Waijung aMG USB Converter library on the path).

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
figDir  = fullfile(rootDir, 'Figures');

model = 'sensorExpoler_Encoder_AMT_103V';
wasLoaded = bdIsLoaded(model);
load_system(fullfile(rootDir, 'Simulink', [model '.slx']));
cleanup = onCleanup(@() local_close(model, wasLoaded));

%% 1. Block diagram
outPng = fullfile(figDir, 'simulink_encoder_model.png');
print(['-s' model], '-dpng', '-r600', outPng);
fprintf('Saved %s\n', outPng);

%% 2. Report view: X4 path and homing only
viewDir = fullfile(tempdir, 'encoder_x4_view');
if ~exist(viewDir, 'dir'), mkdir(viewDir); end
view = 'encoder_x4_view';
if bdIsLoaded(view), close_system(view, 0); end
copyfile(fullfile(rootDir, 'Simulink', [model '.slx']), fullfile(viewDir, [view '.slx']), 'f');
load_system(fullfile(viewDir, [view '.slx']));
keep = {'Host Serial Rx', 'Host Serial Setup', 'reset', 'Reset Button', 'WrapAround2', 'PPR2', 'MULT2', ...
    'Count2Deg2', 'Count2Rad2', 'Angle_to_AngularVelocity_X4', 'Display_pulses X4', 'Display_theta_deg X4', ...
    'Display_theta_rad X4', 'Display_omega X4', 'Display_omega_raw_X4', 'Term_theta_filtered_X4', ...
    'Term_theta_unwrapped_X4', 'home', 'Home Button', 'HomingSequence', 'Count2Deg_home', ...
    'Display_pos_home X4', 'Display_theta_home X4', 'Display_is_homed', 'Display_homing_state'};
blocks = find_system(view, 'SearchDepth', 1, 'Type', 'Block');
for i = 1:numel(blocks)
    if ~any(strcmp(get_param(blocks{i}, 'Name'), keep))
        delete_block(blocks{i});
    end
end
delete_line(find_system(view, 'FindAll', 'on', 'Type', 'line', 'Connected', 'off'));
layout_x4_view(view);
outView = fullfile(figDir, 'simulink_encoder_x4.png');
print(['-s' view], '-dpng', '-r600', outView);
close_system(view, 0);
fprintf('Saved %s\n', outView);

%% 3. Code listings
listings = {
    'WrapAround2',                                      [],      'code_wraparound'
    'WrapAround2',                                      [40 49], 'code_wraparound_core'
    'HomingSequence',                                   [],      'code_homing'
    'Count2Rad2',                                       [],      'code_count2rad'
    'Count2Deg2',                                       [],      'code_count2deg'
    'Angle_to_AngularVelocity_X4/FilteredAngularVelocity', [], 'code_filtered_velocity'};
for k = 1:size(listings, 1)
    blk = [model '/' listings{k, 1}];
    chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', blk);
    code = strsplit(strtrim(chart(1).Script), newline, 'CollapseDelimiters', false);   % keep blank lines
    rows = 1:numel(code);
    if ~isempty(listings{k, 2})
        rows = listings{k, 2}(1):min(listings{k, 2}(2), numel(code));
    end
    draw_listing(code, rows, sprintf('MATLAB Function block: %s   (%s.slx)', listings{k, 1}, model), ...
        fullfile(figDir, listings{k, 3}));
end

%% ---------------------------------------------------------------- helpers
function layout_x4_view(view)
% Compact left-to-right layout of the X4 view; every line is redrawn with autorouting.
pos = {
    'Host Serial Setup',            [  40   20  437  103]
    'Host Serial Rx',               [  40  130  210  420]
    'Home Button',                  [ 455   95  546  139]
    'home',                         [ 470  160  530  190]
    'HomingSequence',               [ 580  100  730  190]
    'Count2Deg_home',               [ 800  110  905  180]
    'WrapAround2',                  [ 290  370  405  443]
    'reset',                        [ 250  480  310  510]
    'Reset Button',                 [ 235  530  326  574]
    'PPR2',                         [ 470  470  530  500]
    'MULT2',                        [ 470  520  530  550]
    'Count2Deg2',                   [ 580  240  685  310]
    'Count2Rad2',                   [ 580  420  685  490]
    'Angle_to_AngularVelocity_X4',  [ 790  440 1000  550]
    'Display_pos_home X4',          [1030   30 1110   65]
    'Display_is_homed',             [1030   80 1110  115]
    'Display_homing_state',         [1030  130 1110  165]
    'Display_theta_home X4',        [1030  180 1110  215]
    'Display_theta_deg X4',         [1030  255 1110  290]
    'Display_pulses X4',            [1030  320 1110  355]
    'Display_theta_rad X4',         [1030  380 1110  415]
    'Display_omega X4',             [1140  440 1220  475]
    'Term_theta_unwrapped_X4',      [1140  488 1160  502]
    'Term_theta_filtered_X4',       [1140  510 1160  524]
    'Display_omega_raw_X4',         [1140  535 1220  570]};
lines = find_system(view, 'FindAll', 'on', 'Type', 'line', 'SegmentType', 'trunk');
conn = {};
for h = lines(:)'
    src = get_param(h, 'SrcPortHandle');
    dst = get_param(h, 'DstPortHandle');
    for d = dst(:)'
        conn(end + 1, :) = {get_param(get_param(src, 'Parent'), 'Name'), get_param(src, 'PortNumber'), ...
            get_param(get_param(d, 'Parent'), 'Name'), get_param(d, 'PortNumber'), get_param(h, 'Name')}; %#ok<AGROW>
    end
end
delete_line(lines);
for k = 1:size(pos, 1)
    set_param([view '/' pos{k, 1}], 'Position', pos{k, 2});
end
named = {};
for k = 1:size(conn, 1)
    h = add_line(view, sprintf('%s/%d', conn{k, 1}, conn{k, 2}), sprintf('%s/%d', conn{k, 3}, conn{k, 4}), ...
        'autorouting', 'smart');
    src = sprintf('%s/%d', conn{k, 1}, conn{k, 2});
    if ~isempty(conn{k, 5}) && ~any(strcmp(named, src))   % label a branched signal once
        set_param(h, 'Name', conn{k, 5});
        named{end + 1} = src; %#ok<AGROW>
    end
end
% the shaded areas and the 'Serial' note around the two Waijung blocks
for h = find_system(view, 'FindAll', 'on', 'Type', 'annotation')'
    p = get_param(h, 'Position');
    switch get_param(h, 'AnnotationType')
        case 'area_annotation'
            if p(2) < 200
                set_param(h, 'Position', [25 8 452 115]);
            else
                set_param(h, 'Position', [25 120 225 445]);
            end
        case 'note_annotation'
            set_param(h, 'Position', [35 425 74 438]);
    end
end
end

function draw_listing(code, rows, header, outBase)
fonts = listfonts;
mono = 'Courier New';
if any(strcmp(fonts, 'Menlo')), mono = 'Menlo'; end
kwColor  = [0.00 0.00 1.00];   % MATLAB editor keyword blue
cmtColor = [0.13 0.55 0.13];   % comment green
numColor = [0.55 0.55 0.55];   % line numbers
nLines = numel(rows);
lineH  = 24;                   % pixels per line
% Drawn off screen so the size does not depend on the display; the height is capped at the 838 px a
% long listing gets on a laptop screen, which is the size used in the report.
fig = figure('Color', 'w', 'Visible', 'off', 'Position', [100 100 860 min(lineH * (nLines + 2.2), 838)], ...
    'Name', header);
ax = axes(fig, 'Position', [0 0 1 1], 'XLim', [0 1], 'YLim', [0 nLines + 2.2], 'YDir', 'reverse');
axis(ax, 'off');
hold(ax, 'on');
rectangle(ax, 'Position', [0.005 0.05 0.99 nLines + 2.1], 'FaceColor', [0.985 0.985 0.985], ...
    'EdgeColor', [0.75 0.75 0.75]);
rectangle(ax, 'Position', [0.005 0.05 0.99 1.2], 'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.75 0.75 0.75]);
% At 600 dpi exportgraphics drops very long text objects, so one-colour lines are drawn as plain text
% and the header is drawn in two pieces (block name, then the model file).
parts = strsplit(header, '   (');
hHead = text(ax, 0.02, 0.65, parts{1}, 'FontName', mono, 'FontSize', 11, 'FontWeight', 'bold', ...
    'Interpreter', 'none');
if numel(parts) > 1
    e = hHead.Extent;
    text(ax, e(1) + e(3), 0.65, ['   (' parts{2}], 'FontName', mono, 'FontSize', 11, 'FontWeight', 'bold', ...
        'Interpreter', 'none');
end
for i = 1:nLines
    y = i + 1.2;
    text(ax, 0.055, y, sprintf('%d', rows(i)), 'FontName', mono, 'FontSize', 11, 'Color', numColor, ...
        'HorizontalAlignment', 'right', 'Interpreter', 'none');
    if startsWith(strtrim(code{rows(i)}), '%')
        text(ax, 0.075, y, code{rows(i)}, 'FontName', mono, 'FontSize', 11, 'Color', cmtColor, ...
            'Interpreter', 'none');
    else
        text(ax, 0.075, y, colorize(code{rows(i)}, kwColor, cmtColor), 'FontName', mono, 'FontSize', 11, ...
            'Interpreter', 'tex');
    end
end
hold(ax, 'off');
exportgraphics(fig, [outBase '.png'], 'Resolution', 600);
close(fig);
fprintf('Saved %s.png (%d lines)\n', outBase, nLines);
end

function s = colorize(line, kwColor, cmtColor)
% TeX string with MATLAB-editor colours: keywords blue, comments green.
iCmt = strfind(line, '%');
if isempty(iCmt)
    codePart = line;  cmtPart = '';
else
    codePart = line(1:iCmt(1) - 1);  cmtPart = line(iCmt(1):end);
end
codePart = texesc(codePart);
for kw = {'function', 'end', 'if', 'elseif', 'else', 'persistent', 'return'}
    codePart = regexprep(codePart, ['(?<![\w])' kw{1} '(?![\w])'], ...
        sprintf('\\\\color[rgb]{%g %g %g}%s\\\\color[rgb]{0 0 0}', kwColor, kw{1}));
end
s = ['\color[rgb]{0 0 0}' codePart];
if ~isempty(cmtPart)
    s = [s sprintf('\\color[rgb]{%g %g %g}', cmtColor) texesc(cmtPart)];
end
end

function s = texesc(s)
% Escape the characters that MATLAB's TeX interpreter treats as markup.
s = strrep(s, '\', '\\');
s = regexprep(s, '([_^{}])', '\\$1');
end

function local_close(model, wasLoaded)
if ~wasLoaded && bdIsLoaded(model)
    close_system(model, 0);   % never save the model
end
end
