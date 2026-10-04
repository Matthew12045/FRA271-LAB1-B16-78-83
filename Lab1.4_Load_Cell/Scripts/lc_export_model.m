%% LC_EXPORT_MODEL Export the real-time weight model as report figures.
%  1) The top-level block diagram of sensorExpoler_loadcell.slx (built by lc_build_model.m):
%     Host Serial Rx -> A0 / 4095 * 3300 -> voltage(mV) -> Moving Average -> calc_Weight
%     -> weight(N), mass(kg).
%  2) The code inside the MATLAB Function block (calc_Weight), read from the model itself and
%     drawn as an editor-style listing.
%  The model is loaded without opening a window and is never saved.
%
% Compatible with MATLAB R2020a through R2026a (needs the Waijung aMG USB Converter library on the path).

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(thisDir);
figDir  = fullfile(rootDir, 'Figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

modelFile = fullfile(rootDir, 'Simulink', 'sensorExpoler_loadcell.slx');
[~, model] = fileparts(modelFile);
wasLoaded = bdIsLoaded(model);
load_system(modelFile);
cleanup = onCleanup(@() local_close(model, wasLoaded));

%% 1. Block diagram
outPng = fullfile(figDir, 'simulink_loadcell_model.png');
print(['-s' model], '-dpng', '-r600', outPng);
fprintf('Saved %s\n', outPng);

%% 2. calc_Weight code listing
chart = sfroot().find('-isa', 'Stateflow.EMChart', 'Path', [model '/calc_Weight']);
code = strsplit(strtrim(chart(1).Script), newline, 'CollapseDelimiters', false);   % keep blank lines

fonts = listfonts;
mono = 'Courier New';
if any(strcmp(fonts, 'Menlo')), mono = 'Menlo'; end

kwColor  = [0.00 0.00 1.00];   % MATLAB editor keyword blue
cmtColor = [0.13 0.55 0.13];   % comment green
numColor = [0.55 0.55 0.55];   % line numbers
nLines   = numel(code);
lineH    = 24;                 % pixels per line
fig = figure('Color', 'w', 'Position', [100 100 860 lineH * (nLines + 2.2)], 'Name', 'calc_Weight');
ax = axes(fig, 'Position', [0 0 1 1], 'XLim', [0 1], 'YLim', [0 nLines + 2.2], 'YDir', 'reverse');
axis(ax, 'off');
hold(ax, 'on');
rectangle(ax, 'Position', [0.005 0.05 0.99 nLines + 2.1], 'FaceColor', [0.985 0.985 0.985], ...
    'EdgeColor', [0.75 0.75 0.75]);
rectangle(ax, 'Position', [0.005 0.05 0.99 1.2], 'FaceColor', [0.93 0.93 0.93], 'EdgeColor', [0.75 0.75 0.75]);
text(ax, 0.02, 0.65, sprintf('MATLAB Function block: calc\\_Weight   (%s.slx)', texesc(model)), ...
    'FontName', mono, 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'tex');
for k = 1:nLines
    y = k + 1.2;
    text(ax, 0.055, y, sprintf('%d', k), 'FontName', mono, 'FontSize', 11, 'Color', numColor, ...
        'HorizontalAlignment', 'right', 'Interpreter', 'none');
    text(ax, 0.075, y, colorize(code{k}, kwColor, cmtColor), 'FontName', mono, 'FontSize', 11, ...
        'Interpreter', 'tex');
end
hold(ax, 'off');
outCode = fullfile(figDir, 'code_calc_weight.png');
exportgraphics(fig, outCode, 'Resolution', 600);
fprintf('Saved %s\n', outCode);

%% ---------------------------------------------------------------- helpers
function s = colorize(line, kwColor, cmtColor)
% TeX string with MATLAB-editor colours: keywords blue, comments green.
iCmt = strfind(line, '%');
if isempty(iCmt)
    codePart = line;  cmtPart = '';
else
    codePart = line(1:iCmt(1) - 1);  cmtPart = line(iCmt(1):end);
end
codePart = texesc(codePart);
for kw = {'function', 'end'}
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
