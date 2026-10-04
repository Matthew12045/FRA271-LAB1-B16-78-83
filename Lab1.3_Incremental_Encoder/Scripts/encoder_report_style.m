function U = encoder_report_style()
%% ENCODER_REPORT_STYLE Shared look of the Lab 1.3 report figures (same as the Lab 1.1/1.2 figures).
%
% Syntax:
%   U = encoder_report_style();
%   fig = U.figure('name', heightPx);   U.axes(ax);
%   U.note(ax, text, 'ne');             U.save(fig, outBase);
%
% Colours: X1 blue, X2 coral, X4 purple (slots 1, 2, 4 of the Lab 1.1/1.2 palette;
% slot 3 green is skipped because it cannot be told from coral under deuteranopia).
% Channel A uses blue and channel B coral. Every series also has its own marker.
%
% Compatible with MATLAB R2020a through R2026a.

U.mode   = [0.12 0.45 0.80; 0.85 0.22 0.18; 0.55 0.27 0.68];
U.marker = {'o', 's', 'd'};
U.chA    = [0.12 0.45 0.80];
U.chB    = [0.85 0.22 0.18];
U.ink    = [0.12 0.12 0.15];
U.grey   = [0.62 0.62 0.62];
U.pale   = @(c, w) c * (1 - w) + w;
U.figure = @new_figure;
U.axes   = @style_axes;
U.note   = @pin_note;
U.save   = @save_figure;
end

function fig = new_figure(name, heightPx)
if nargin < 2, heightPx = 560; end
fig = figure('Color', 'w', 'Position', [100 100 860 heightPx], 'Name', name);
set(fig, 'DefaultTextInterpreter', 'tex', ...
         'DefaultAxesTickLabelInterpreter', 'tex', ...
         'DefaultLegendInterpreter', 'tex');
end

function style_axes(ax)
hold(ax, 'on');
set(ax, 'FontSize', 11, 'Box', 'on', 'GridAlpha', 0.20, 'LineWidth', 1.0);
grid(ax, 'on');
end

function h = pin_note(ax, str, where)
% Characteristics box pinned inside the axes: where = 'ne' | 'nw' | 'se' | 'sw' | [x y] (normalized, top-left).
if ischar(where)
    xs = struct('e', [0.985 1], 'w', [0.015 0]);
    ys = struct('n', [0.97 1], 's', [0.035 0]);
    xx = xs.(where(2));  yy = ys.(where(1));
    pos = [xx(1) yy(1)];
    ha = 'left';   if xx(2), ha = 'right'; end
    va = 'bottom'; if yy(2), va = 'top'; end
else
    pos = where;  ha = 'left';  va = 'top';
end
h = text(ax, pos(1), pos(2), str, 'Units', 'normalized', 'HorizontalAlignment', ha, ...
    'VerticalAlignment', va, 'BackgroundColor', [0.98 0.98 0.98], 'EdgeColor', [0.75 0.75 0.75], ...
    'FontSize', 9.5, 'Margin', 5, 'Interpreter', 'tex');
end

function save_figure(fig, outBase)
drawnow;
exportgraphics(fig, [outBase '.png'], 'Resolution', 600);
savefig(fig, [outBase '.fig']);
fprintf('Saved %s.png\n', outBase);
end
