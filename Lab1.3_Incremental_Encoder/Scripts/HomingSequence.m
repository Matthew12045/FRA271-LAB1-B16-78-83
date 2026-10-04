function [pos_home, is_homed, state] = HomingSequence(pos_in, home_btn)
%#codegen
% Homing for an incremental encoder with only A/B wired (no index pulse):
% turn the shaft to the home mark, press Home; the count becomes zero once
% the shaft has stayed still for STILL_N samples. state: 0 = not homed,
% 1 = waiting for standstill, 2 = homed. pos_in, pos_home in counts.
persistent st offset prevBtn anchor nStill
STILL_N   = 200;   % 200 ms at Ts = 1 ms
STILL_TOL = 1;     % counts
if isempty(st)
    st = 0; offset = 0; prevBtn = false; anchor = pos_in; nStill = 0;
end

btn = home_btn ~= 0;
if btn && ~prevBtn              % rising edge of Home: start (re)homing
    st = 1;  anchor = pos_in;  nStill = 0;
end
prevBtn = btn;

if abs(pos_in - anchor) <= STILL_TOL
    nStill = nStill + 1;        % shaft still
else
    anchor = pos_in;  nStill = 0;
end

if st == 1 && nStill >= STILL_N
    offset = pos_in;            % latch the home position
    st = 2;
end

pos_home = pos_in - offset;
is_homed = st == 2;
state    = st;
end
