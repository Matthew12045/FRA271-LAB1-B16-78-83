%% PLOT_SCHMITT_TRIGGER Wrapper script for Schmitt Trigger Analysis
%  Calls schmitt_trigger_analysis to plot the real-time potentiometer signal change
%  and Schmitt trigger activation curves with consistent laboratory styling.
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
