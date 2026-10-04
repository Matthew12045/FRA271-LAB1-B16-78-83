function theta_deg = Count2Deg(pulses, PPR, MULT)
theta_deg = (pulses / (PPR * MULT)) * 360;
