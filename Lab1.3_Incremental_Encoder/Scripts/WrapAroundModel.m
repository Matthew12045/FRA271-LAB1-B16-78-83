function pos_count = WrapAroundModel(raw_count, reset)
%#codegen
persistent prev acc nBlank
MAXC          = 65536;      % hardware counter modulus
HALF          = MAXC/2;
BLANK_SAMPLES = 150;

if isempty(prev) || isempty(acc) || isempty(nBlank)
    prev = 0; acc = 0; nBlank = 0;
end

rawd  = double(raw_count);
valid = isfinite(rawd);
raw   = mod(rawd, MAXC);          % NaN/Inf -> NaN, never used unless valid

% --- reset first, so it can't be swallowed by a bad sample ---
if reset ~= 0
    acc = 0;
    if valid
        prev   = raw;                 % re-latch immediately
        nBlank = BLANK_SAMPLES;       % skip re-blanking
    else
        nBlank = BLANK_SAMPLES - 1;   % next valid sample re-latches prev, no delta
    end
    pos_count = 0;  return
end

% --- reject invalid samples before they touch the state ---
if ~valid
    pos_count = acc;  return
end

% --- power-up blanking (also serves as the re-latch after an invalid reset) ---
if nBlank < BLANK_SAMPLES
    nBlank    = nBlank + 1;
    prev      = raw;
    pos_count = acc;  return
end

% --- unwrap ---
delta = raw - prev;
if delta >= HALF
    delta = delta - MAXC;
elseif delta < -HALF
    delta = delta + MAXC;
end
acc       = acc + delta;
prev      = raw;
pos_count = acc;
end