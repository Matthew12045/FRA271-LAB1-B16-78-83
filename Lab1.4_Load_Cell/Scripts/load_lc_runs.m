function [T, sig] = load_lc_runs(dataDir)
%% LOAD_LC_RUNS Steady-state output of every load cell recording '<mass>kg_<run>.mat' in dataDir.
%
% Syntax:
%   T = load_lc_runs(dataDir);
%   [T, sig] = load_lc_runs(dataDir);
%
% Each file is a 10 s Simulink log at 1 kHz with the raw ADC count A0 (12-bit, 0-4095).
% The voltage is computed from A0 exactly as in the Simulink model, V = A0 * 3.3 / 4095,
% and averaged over the steady window t >= 0.5 s (the ADC/USB start-up of the first
% ~50 ms and the 0.5 s fill of the model's 500-sample moving average are skipped).
% The logged 'mV' signal is that moving average, so the raw A0 is used instead.
% Disturbed intervals listed in EXCLUDE are left out (the load was touched while logging).
%
% Output T (one row per file, sorted by run then mass):
%   File, Mass_kg (digital scale), Run, A0_mean, V_mean (V), V_std (V, sample SD),
%   V_sem (V), N (samples used)
% Output sig(k): t, A0, V and the logical mask of the samples used, for file T.File(k).
%
% Compatible with MATLAB R2020a through R2026a.

EXCLUDE = {'8.883kg_1.mat', [1.7 4.0]};      % bump in A0 from 1.8 to 3.8 s (see lc_signal_check)
T_START = 0.5;

files = dir(fullfile(dataDir, '*kg_*.mat'));
n = numel(files);
File = strings(n, 1);  Mass_kg = nan(n, 1);  Run = nan(n, 1);
A0_mean = nan(n, 1);  V_mean = nan(n, 1);  V_std = nan(n, 1);  V_sem = nan(n, 1);  N = nan(n, 1);
sig = struct('t', {}, 'A0', {}, 'V', {}, 'used', {});
for k = 1:n
    tok = regexp(files(k).name, '^([0-9.]+)kg_([0-9]+)\.mat$', 'tokens', 'once');
    if isempty(tok), continue; end
    S = load(fullfile(dataDir, files(k).name));
    e = S.data.get('A0');
    t = e.Values.Time(:);
    a = double(squeeze(e.Values.Data));
    used = t >= T_START;
    iEx = find(strcmp(EXCLUDE(:, 1), files(k).name));
    for j = iEx(:)'
        w = EXCLUDE{j, 2};
        used = used & ~(t >= w(1) & t <= w(2));
    end
    v = a * 3.3 / 4095;
    File(k) = files(k).name;
    Mass_kg(k) = str2double(tok{1});
    Run(k) = str2double(tok{2});
    A0_mean(k) = mean(a(used));
    V_mean(k) = mean(v(used));
    V_std(k) = std(v(used));
    V_sem(k) = V_std(k) / sqrt(nnz(used));
    N(k) = nnz(used);
    sig(k).t = t;  sig(k).A0 = a;  sig(k).V = v;  sig(k).used = used;
end
keep = ~isnan(Mass_kg);
T = table(File, Mass_kg, Run, A0_mean, V_mean, V_std, V_sem, N);
T = T(keep, :);
sig = sig(keep);
[T, order] = sortrows(T, {'Run', 'Mass_kg'});
sig = sig(order);
end
