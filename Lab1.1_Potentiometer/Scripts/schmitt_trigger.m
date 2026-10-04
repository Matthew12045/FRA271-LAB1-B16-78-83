%% SCHMITT_TRIGGER Generate Schmitt Trigger Real-Time Signal & Switching Figure
%  Plots the real-time potentiometer input voltage and Schmitt trigger digital output
%  with clean laboratory styling matching other potentiometer experiments.
%
% Compatible with MATLAB R2020a through R2026a and MATLAB Agentic AI Toolkit.

clear; close all; clc;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
analysisScript = fullfile(thisDir, 'schmitt_trigger_analysis.m');

if exist(analysisScript, 'file')
    run(analysisScript);
else
    schmitt_trigger_analysis;
end
