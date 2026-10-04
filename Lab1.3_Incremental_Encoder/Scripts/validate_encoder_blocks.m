%% validate_encoder_blocks -- regression check for the Lab 1.3 Simulink blocks
% against all 62 recorded runs in ../Data (60 one-rev + 2 TrunBack).  Run it
% in a fresh MATLAB session:
%   >> cd('<...>/Lab1.3_Incremental_Encoder/Scripts'); validate_encoder_blocks
%
% Checks
%   1. Count2Rad / Count2Deg / Count2Speed / HomingSequence basic behaviour.
%   2. WrapAround synthetic forward + backward wrap across 65535/0.
%   3. Every .mat file of the campaign:
%        - pos_count == 0 during the 150-sample startup blank,
%        - pos_count(k) == raw(k) - raw(zeroRef) afterwards  (so every real
%          delta, including the -1..-8 backlash steps, passes through and
%          nothing from the startup transient leaks in),
%        - number of negative steps preserved,
%        - final value correct.
% Keeping this as a SCRIPT (not a function) lets `clear <name>` reset the
% persistent states between tests.

here = fileparts(mfilename('fullpath'));
addpath(here);
dataDir = fullfile(here, '..', 'Data');

fprintf('== unit checks ==\n');
assert(abs(Count2Rad(2048, 2048, 1) - 2*pi) < 1e-12, 'Count2Rad AMT X1');
assert(abs(Count2Deg(96, 24, 4)   - 360)  < 1e-9,  'Count2Deg Bourns X4');
assert(abs(Count2Rad(-48, 24, 2)  + 2*pi) < 1e-12, 'Count2Rad negative');
clear Count2Speed
assert(Count2Speed(1.0, 0.001, 1.0) == 0, 'Count2Speed first sample');
assert(abs(Count2Speed(1.5, 0.001, 1.0) - 500) < 1e-6, 'Count2Speed step');
clear HomingSequence
[p, h] = HomingSequence(2.5, false);  assert(~h && abs(p-2.5)<1e-12, 'homing pre');
[p, h] = HomingSequence(2.6, true);   assert(h  && abs(p-0.0)<1e-12, 'homing edge');
[p, h] = HomingSequence(3.0, true);   assert(abs(p-0.4)<1e-12, 'homing hold');
fprintf('   unit checks OK\n');

fprintf('== synthetic wrap checks (MAX_COUNT = 65536) ==\n');
xf = [repmat(65530,151,1); 65531; 65532; 65533; 65534; 65535; 0; 1; 2; 3];
pf = run_wrap(xf);
assert(pf(end) == 9 && pf(157) == 6 && pf(158) == 7, 'forward wrap');
xb = [repmat(5,151,1); 4; 3; 2; 1; 0; 65535; 65534; 65533];
pb = run_wrap(xb);
assert(pb(end) == -8 && pb(157) == -6, 'backward wrap');
clear WrapAround
[~] = WrapAround(int16(-1), 65536, true);      % int16 two's complement state
p = WrapAround(int16(0), 65536, false);
assert(p == 0, 'int16 input');
fprintf('   forward wrap +9, backward wrap -8, int16 input OK\n');

fprintf('== all recorded runs ==\n');
files = dir(fullfile(dataDir, '*.mat'));
[~, ix] = sort({files.name}); files = files(ix);
B = 150; nPass = 0; fails = {};
maxAbsStep = 0; nNegTotal = 0;
for k = 1:numel(files)
    fn = files(k).name;
    S  = load(fullfile(dataDir, fn), 'data');
    ds = S.data;
    tok = regexp(fn, '_X([124])_', 'tokens', 'once');
    want = ['EncoderX' tok{1}];
    x = []; t = [];
    for i = 1:ds.numElements
        if strcmp(ds{i}.Name, want)
            x = double(ds{i}.Values.Data); t = ds{i}.Values.Time;
        end
    end
    N = numel(x);
    if isempty(x)
        fails{end+1} = sprintf('%s: channel %s not found', fn, want); %#ok<SAGROW>
        continue
    end

    pos = zeros(N,1);
    for n = 1:N
        if n == 1
            pos(n) = WrapAround(x(n), 65536, true);  % reset at t=0
        else
            pos(n) = WrapAround(x(n), 65536, false);
        end
    end

    zeroRef  = x(B+1);                       % first sample after the blank
    expected = x - zeroRef;
    okBlank  = all(pos(1:B+1) == 0);
    okTrack  = max(abs(pos(B+2:end) - expected(B+2:end))) == 0;
    okNeg    = nnz(diff(pos(B+1:end)) < 0) == nnz(diff(x(B+1:end)) < 0);
    okFinal  = pos(end) == expected(end);
    maxAbsStep = max(maxAbsStep, max(abs(diff(pos(B+1:end)))));
    nNegTotal  = nNegTotal + nnz(diff(x(B+1:end)) < 0);
    if okBlank && okTrack && okNeg && okFinal
        nPass = nPass + 1;
    else
        fails{end+1} = sprintf('%s: blank=%d track=%d neg=%d final=%d (pos=%d exp=%d)', ...
            fn, okBlank, okTrack, okNeg, okFinal, pos(end), expected(end)); %#ok<SAGROW>
    end
end

fprintf('   %d/%d files passed\n', nPass, numel(files));
fprintf('   total negative (backward) steps preserved: %d\n', nNegTotal);
fprintf('   largest single-sample accepted step: %d counts\n', maxAbsStep);
if isempty(fails)
    fprintf('   RESULT: ALL PASS\n');
else
    fprintf('   FAILURES:\n'); fprintf('     %s\n', fails{:});
end

% ------------------------------------------------------------------------
function p = run_wrap(x)
% reset on first call -> independent of previous persistent state.
% Then 150 blank samples, so integration starts at sample B+2 and the zero
% reference is x(B+1) = x(151).
p = zeros(numel(x),1);
for n = 1:numel(x)
    p(n) = WrapAround(x(n), 65536, n == 1);
end
end
