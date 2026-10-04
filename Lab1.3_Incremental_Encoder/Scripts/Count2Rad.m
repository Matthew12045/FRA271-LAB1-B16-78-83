function theta_rad = Count2Rad(pulses, PPR, MULT)
theta_rad = (pulses / (PPR * MULT)) * 2*pi;
