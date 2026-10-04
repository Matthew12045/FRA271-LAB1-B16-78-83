function [x, t] = load_encoder_signal(src, name)
%% LOAD_ENCODER_SIGNAL Read one logged signal from an encoder recording.
%
% Syntax:
%   [x, t] = load_encoder_signal(matFile, name)
%   [x, t] = load_encoder_signal(ds, name)
%
% src   path to a .mat file whose variable data is a Simulink.SimulationData.Dataset,
%       or that Dataset itself (load once, read many signals)
% name  element name, e.g. 'EncoderX4', 'A0', 'pulses X4', 'theta_deg X4', 'omega_final_X4'
%
% The recording models lost the first letter of some labels ('heta_deg X4',
% 'heta_rad X2'), so a name that is not found is tried again without its first
% character. x is returned as a double column and t in seconds.
%
% Compatible with MATLAB R2020a through R2026a.

if ischar(src) || isstring(src)
    S  = load(src, 'data');
    ds = S.data;
else
    ds = src;
end
names = ds.getElementNames();
k = find(strcmp(names, name), 1);
if isempty(k) && strlength(name) > 1
    k = find(strcmp(names, extractAfter(name, 1)), 1);
end
if isempty(k)
    error('load_encoder_signal:missing', 'No signal named ''%s''.', name);
end
v = ds{k}.Values;
x = double(v.Data(:));
t = v.Time(:);
end
