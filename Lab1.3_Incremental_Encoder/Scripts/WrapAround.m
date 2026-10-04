function pos_count = WrapAround(raw_count, MAX_COUNT, reset)
% WrapAround: raw hardware count -> continuous signed pulse count.
% Handles: 16-bit modulo wrap (MAX_COUNT = timer period, 65536 here),
% startup leftover/clear transient (first BLANK_SAMPLES samples blanked),
% explicit re-zero (reset ~= 0), and real backward/backlash steps.
% NOTE: keep the `if isempty(prev)` first-init form -- the Simulink MATLAB
% Function block parser rejects `first = isempty(prev); if first ...`.
persistent prev acc nBlank
MAXC = double(MAX_COUNT);
raw  = mod(double(raw_count), MAXC);     % uint16/int16/uint32 -> 0..MAXC-1
if isempty(prev)
    prev = raw; acc = 0; nBlank = 0;
end

% ---------------- startup blanking / explicit re-zero --------------------
BLANK_SAMPLES = 150;    % 150 ms at the lab's 1 ms sample time
if reset ~= 0
    acc = 0; prev = raw; nBlank = 0;
    pos_count = acc;
    return
end
if nBlank < BLANK_SAMPLES
    nBlank = nBlank + 1;
    prev = raw;
    pos_count = acc;
    return
end

% ---------------- signed delta with modulo wrap correction ---------------
delta = raw - prev;
if delta > MAXC/2
    delta = delta - MAXC;       % 0 -> MAXC-1 while decrementing (backward)
elseif delta < -MAXC/2
    delta = delta + MAXC;       % MAXC-1 -> 0 while incrementing (forward)
end
acc = acc + delta;
prev = raw;
pos_count = acc;
