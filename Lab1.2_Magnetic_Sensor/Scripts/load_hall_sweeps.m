function H = load_hall_sweeps(rootDir)
%% LOAD_HALL_SWEEPS Load every unique static DRV5055A2 sweep (North/South, with/without shield).
%
% Syntax:
%   H = load_hall_sweeps(rootDir)
%
% Output struct H:
%   H.d                 [cm]  19 distances (0.1 : 0.2 : 3.7)
%   H.VQ, H.S           1650 mV, 30 mV/mT (DRV5055A2 at 3.3 V, TA = 25 C; same as Simulink calc_Flux)
%   H.VL                [200 3100] mV, datasheet linear output range (0.2 V to VCC - 0.2 V)
%   H.(cond).name       'North' | 'North_Sh' | 'South' | 'South_Sh'
%   H.(cond).sweeps     sweep labels for legends
%   H.(cond).V          [mV]  mean voltage per point, size 19 x nSweeps
%   H.(cond).SD         [mV]  within-point standard deviation (noise)
%   H.(cond).B          [mT]  (V - VQ) / S
%   H.(cond).linear     true where every sweep is inside VL (valid B)
%
% Each file is a 32 s Simulink log at 1 kHz; the first 0.5 s (500 samples) is
% discarded as start-up transient and samples are kept up to 32,000.
%
% Duplicate copies are excluded: Data_2/South_*cm.mat and Data_2/South_Sh_*cm.mat
% are byte-identical to Data/, and Data_2/North*_cm_2, Data_3/North*_cm_2 and
% Data_3/North*_cm_3 repeat Data_2 or Data_3 recordings. The genuine Data_2 South
% sweeps are the files without the 'cm' suffix (e.g. South_0.1.mat).

H.d  = (0.1:0.2:3.7)';
H.VQ = 1650;
H.S  = 30;
H.VL = [200 3100];

src.North    = {'Data', '%s_%.1fcm.mat'; 'Data_2', '%s_%.1fcm.mat'; 'Data_3', '%s_%.1fcm.mat'};
src.North_Sh = src.North;
src.South    = {'Data', '%s_%.1fcm.mat'; 'Data_2', '%s_%.1f.mat';   'Data_3', '%s_%.1f.mat'};
src.South_Sh = {'Data', '%s_%.1fcm.mat'; 'Data_2', '%s_%.1f.mat';   'Data_3', '%s_%.1f.mat'; ...
                'Data_4', '%s_%.1f.mat'; 'Data_5', '%s_%.1f.mat'};

conds = fieldnames(src);
for c = 1:numel(conds)
    cn = conds{c};
    S  = src.(cn);
    nS = size(S, 1);
    V  = nan(numel(H.d), nS);
    SD = V;
    for s = 1:nS
        for i = 1:numel(H.d)
            fn = fullfile(rootDir, S{s, 1}, sprintf(S{s, 2}, cn, H.d(i)));
            L  = load(fn);
            ds = L.data;
            names = ds.getElementNames();
            iv = find(contains(lower(names), 'volt'), 1);
            v  = double(ds.getElement(names{iv}).Values.Data(:));
            v  = v(501:min(numel(v), 32000));
            V(i, s)  = mean(v);
            SD(i, s) = std(v);
        end
    end
    E.name   = cn;
    E.sweeps = arrayfun(@(k) sprintf('Sweep %d (%s)', k, S{k, 1}), 1:nS, 'UniformOutput', false);
    E.V      = V;
    E.SD     = SD;
    E.B      = (V - H.VQ) / H.S;
    E.linear = all(V > H.VL(1) & V < H.VL(2), 2);
    H.(cn)   = E;
end
end
