%% tune_filtered_velocity.m -- choose fc_theta / fc_omega for Bourns and AMT
% Uses the recorded 1 ms runs through the exact model blocks
% (WrapAroundModel + Count2Rad) and the new FilteredAngularVelocity core.
%
% Run from this folder:  tune_filtered_velocity

here    = fileparts(mfilename('fullpath'));
dataDir = fullfile(here, '..', 'Data');
addpath(here);
Ts = 0.001;

% {file, PPR, MULT, t_motion_start, t_reversal, t_end}
runs = {
    'bourns_X1_TrunBack.mat',   24, 1,  4.0, 16.368, 30.0;
    'bourns_X1_1.mat',          24, 1,  2.2, 47.985, 50.0;
    'AMT_X1_TrunBack.mat',    2048, 1,  4.0, 16.5,   30.0;
    'AMT_X1_1.mat',           2048, 1,  1.2, 14.0,   16.0;
    'AMT_X2_1.mat',           2048, 2,  1.2, 14.0,   16.0;
    'AMT_X4_1.mat',           2048, 4,  1.2, 14.0,   16.0;
};

fcSweep = containers.Map( ...
    {'bourns_X1_TrunBack.mat','bourns_X1_1.mat','AMT_X1_TrunBack.mat','AMT_X1_1.mat','AMT_X2_1.mat','AMT_X4_1.mat'}, ...
    {[0.25 0.5 1 2],          [0.25 0.5 1 2],  [5 10 15 20],        [5 10 15 20],      [10 15 20 30],    [20 30 40 60]});

fprintf('Ts = %g s\n', Ts);
fprintf('\n%-24s %-8s %-8s | %-9s %-9s | %-9s %-9s %-9s | %-8s %-9s %-9s\n', ...
    'file', 'fc_theta', 'fc_omega', 'stat_std', 'stat_max', 'fwd_mean', 'ref_mean', 'fwd_ripple', 'rev_del', 'peak', 'lag');
fprintf('%s\n', repmat('-', 1, 140));

for r = 1:size(runs,1)
    fn = runs{r,1};
    fpath = fullfile(dataDir, fn);
    if ~isfile(fpath), fprintf('%-24s (missing)\n', fn); continue; end
    S = load(fpath, 'data'); ds = S.data;
    tok = regexp(fn, '_X([124])_', 'tokens', 'once');
    want = ['EncoderX' tok{1}];
    x = []; t = [];
    for i = 1:ds.numElements
        if strcmp(ds{i}.Name, want)
            x = double(ds{i}.Values.Data); t = ds{i}.Values.Time;
        end
    end
    PPR = runs{r,2}; MULT = runs{r,3};
    N = numel(x);

    clear WrapAroundModel
    pos = zeros(N,1);
    for n = 1:N
        pos(n) = WrapAroundModel(x(n), 0);
    end
    rad = (pos / (PPR*MULT)) * 2*pi;

    % smoothed reference velocity (centred 1 s window, metrics only)
    W = 500;
    refv = zeros(N,1);
    refv(W+1:N-W) = (rad(2*W+1:N) - rad(1:N-2*W)) / (2*W*Ts);
    [~, irev] = max(rad);

    t0 = runs{r,4};
    statMask = t > max(0.5, t0-3.0) & t < t0 - 0.2;
    if ~any(statMask), statMask = t > 0.5 & t < 1.5; end
    t1 = t0 + 2; t2 = runs{r,5} - 2;
    if t2 <= t1, t1 = t0 + 1; t2 = runs{r,5} - 1; end
    fwdMask = t > t1 & t < t2;
    refMean = mean(refv(fwdMask));

    rawStd = std(rad(statMask)); rawMax = max(abs(diff(rad(statMask))/Ts));
    fprintf('%-24s %-8s %-8s | %-9.3f %-9.3f | %-9s %-9.4f %-9s | %-8s %-9.3f %-9s\n', ...
        fn, 'RAW', '-', rawStd, rawMax, '-', refMean, '-', '-', max(abs(diff(rad)/Ts)), '-');

    fcs = fcSweep(fn);
    for fcT = fcs
        for fcO = [0 5 10 20]
            if fcO > 0 && fcO <= fcT/2, continue; end   % velocity LPF should be lighter
            useO = fcO > 0;
            clear FilteredAngularVelocity
            om = zeros(N,1);
            for n = 1:N
                [om(n), ~, ~, ~] = FilteredAngularVelocity(rad(n), 0, Ts, fcT, fcO, useO, false, 2*pi);
            end
            statStd = std(om(statMask));
            statMax = max(abs(om(statMask)));
            fwdMean = mean(om(fwdMask));
            fwdRipple = std(om(fwdMask) - refv(fwdMask));
            after = find(om(irev:end) < 0, 1, 'first');
            if isempty(after), revDelay = NaN; else, revDelay = (after-1)*Ts; end
            % lag via cross-correlation of omega with the centred reference
            [xc, lags] = xcorr(om(fwdMask) - mean(om(fwdMask)), refv(fwdMask) - mean(refv(fwdMask)), 1000, 'coeff');
            [~, il] = max(xc); lagS = lags(il)*Ts;
            fprintf('%-24s %-8.2f %-8.2f | %-9.3f %-9.3f | %-9.4f %-9.4f %-9.4f | %-8.3f %-9.3f %-9.3f\n', ...
                fn, fcT, fcO, statStd, statMax, fwdMean, refMean, fwdRipple, revDelay, max(abs(om)), lagS);
        end
    end
    fprintf('\n');
end

% ---- comparison figure: raw vs filtered -----------------------------------
pairs = {
    'bourns_X1_TrunBack.mat', 'EncoderX1', 24, 1, 0.5, 5;
    'AMT_X1_TrunBack.mat',    'EncoderX1', 2048, 1, 10, 20;
};
for k = 1:size(pairs,1)
    fn = fullfile(dataDir, pairs{k,1});
    if ~isfile(fn), continue; end
    S = load(fn, 'data'); ds = S.data;
    x = double(ds.getElement(pairs{k,2}).Values.Data);
    t = ds.getElement(pairs{k,2}).Values.Time;
    N = numel(x); PPR = pairs{k,3}; MULT = pairs{k,4};
    fcT = pairs{k,5}; fcO = pairs{k,6};
    clear WrapAroundModel
    pos = zeros(N,1);
    for n = 1:N, pos(n) = WrapAroundModel(x(n), 0); end
    rad = (pos/(PPR*MULT))*2*pi;
    clear FilteredAngularVelocity
    omRaw = zeros(N,1);
    for n = 1:N
        [omRaw(n),~,~,~] = FilteredAngularVelocity(rad(n), 0, Ts, 1e9, 1e9, false, false, 2*pi);
    end
    clear FilteredAngularVelocity
    omF = zeros(N,1); thF = zeros(N,1);
    for n = 1:N
        [omF(n), ~, thF(n), ~] = FilteredAngularVelocity(rad(n), 0, Ts, fcT, fcO, true, false, 2*pi);
    end
    figure('Color','w','Position',[100 100 1000 700], 'Visible', 'off');
    subplot(3,1,1); plot(t, x, 'k'); grid on; ylabel('raw count');
    title(sprintf('%s: recorded data', pairs{k,1}), 'Interpreter', 'none');
    subplot(3,1,2); plot(t, rad, 'b'); hold on; plot(t, thF, 'r'); grid on;
    ylabel('angle [rad]'); legend('unwrapped \theta','filtered \theta','Location','best');
    subplot(3,1,3); plot(t, omRaw, 'Color', [0.7 0.7 0.7]); hold on; plot(t, omF, 'r'); grid on;
    xlabel('time [s]'); ylabel('\omega [rad/s]');
    legend('raw difference', sprintf('fc_\\theta=%.2g Hz + fc_\\omega=%.2g Hz', fcT, fcO), 'Location','best');
    out = fullfile(here, '..', 'Figures', sprintf('%s_filtered_velocity_tuning.png', regexprep(pairs{k,1}, '\.mat$', '')));
    exportgraphics(gcf, out, 'Resolution', 600);
    fprintf('figure saved: %s\n', out);
end
