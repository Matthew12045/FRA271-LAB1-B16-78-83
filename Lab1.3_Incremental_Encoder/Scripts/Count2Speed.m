function omega_rad_s = Count2Speed(theta_rad, Ts, alpha)
%#codegen
% Count2Speed -- angular velocity [rad/s], backward difference + first-order
% exponential smoothing.  Paste into a MATLAB Function block named
% "Count2Speed".
%
% Ports   theta_rad : from Count2Rad
%         Ts        : sample time [s] -- 0.001 in this lab (Constant block)
%         alpha     : smoothing factor, 0 < alpha <= 1 (Constant block)
%                       1.0  = raw 1 ms difference (very spiky, see below)
%                       0.05 = ~20 ms time constant at Ts = 1 ms  <- good
%                              starting point for the report figures
%         -> omega_rad_s  (0 until the second sample)
%
% Why smoothing is not optional here:
%   One count = 2*pi/countsPerRev rad.  At Ts = 1 ms that is a 3.07 rad/s
%   quantization step for AMT X1 (0.77 for X4, 262 for Bourns X1).  The
%   recorded AMT runs also update in bursts: after the first 0.5 s the
%   median |raw step| is 0-1 counts but single-sample steps reach 99-232
%   counts, so an unsmoothed 1 ms derivative is dominated by spikes.
%   For a single steady-state number, use the average over the moving part
%   of the run instead:  omega_avg = (theta_end - theta_start)/(t_end - t_start).
%
% If you want a different filter (moving average, Discrete FIR Filter,
% Discrete Derivative + Low Pass Filter), you can skip this block entirely.
persistent prev w
if isempty(prev)
    prev = theta_rad; w = 0;
end
if nargin < 3 || isempty(alpha)
    alpha = 1;
end
alpha = min(max(alpha, 0), 1);      % clamp to [0,1]
raw_w = (theta_rad - prev) / Ts;
w     = w + alpha * (raw_w - w);
prev  = theta_rad;
omega_rad_s = w;
