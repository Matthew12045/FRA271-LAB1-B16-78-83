function [omega, theta_unwrapped, theta_filtered, omega_raw] = FilteredAngularVelocity(theta_in, reset, Ts, fc_theta, fc_omega, enable_omega_filter, enable_unwrap, wrap_period)
%#codegen
% FilteredAngularVelocity -- causal angle-to-angular-velocity pipeline.
%
%   [omega, theta_unwrapped, theta_filtered, omega_raw] = ...
%       FilteredAngularVelocity(theta_in, reset, Ts, fc_theta, fc_omega, ...
%                               enable_omega_filter, enable_unwrap, wrap_period)
%
% Pipeline (matches the task specification):
%   theta_in -> [unwrap, if enabled] -> [1st-order LPF @ fc_theta]
%            -> [backward difference / Ts] -> [optional LPF @ fc_omega] -> omega
%
% Inputs
%   theta_in           : angle [rad].  If it comes from WrapAround/Count2Rad
%                        it is ALREADY an accumulated (unwrapped) position,
%                        so leave enable_unwrap = false.  Set true only when
%                        theta_in itself wraps.
%   reset              : ~= 0 re-initialises every state from theta_in and
%                        outputs omega = 0 (no spike after a counter reset).
%   Ts                 : effective sensor update interval [s] (1 ms here).
%   fc_theta           : angle LPF cutoff [Hz], 0 < fc_theta < 1/(2*Ts).
%   fc_omega           : velocity LPF cutoff [Hz] (used only if enabled).
%   enable_omega_filter: true/false, bypass for the light velocity LPF.
%   enable_unwrap      : true/false, stateful unwrap of a wrapped angle.
%   wrap_period        : wrap period [rad] (2*pi) or [deg] (360).
%
% Outputs
%   omega              : final angular velocity [rad/s].
%   theta_unwrapped    : angle after the (optional) unwrap [rad].
%   theta_filtered     : angle after the causal LPF [rad] (diagnostic).
%   omega_raw          : velocity BEFORE the optional velocity LPF [rad/s].
%
% Initialisation / startup behaviour
%   On the first valid sample (or right after reset) every state is set to
%   theta_in and omega is forced to 0, so no artificial startup impulse and
%   no drift from an implicit zero initial condition.
%
% Causality / timing
%   Pure sample-by-sample processing at Ts.  No gradient()/zero-phase
%   filtering; safe for live Simulink execution and code generation.

persistent prev_raw prev_unwrapped theta_f prev_theta_f omega_f initialised

if isempty(initialised)
    initialised = false;
    prev_raw = 0; prev_unwrapped = 0; theta_f = 0; prev_theta_f = 0; omega_f = 0;
end

valid = isfinite(theta_in);

if ~valid
    % Hold the last outputs; do not let a bad sample corrupt the state.
    omega = omega_f; theta_unwrapped = prev_unwrapped;
    theta_filtered = theta_f; omega_raw = 0;
    return
end

if ~initialised || reset ~= 0
    % First valid sample or explicit re-zero: initialise from the sample.
    prev_raw       = theta_in;
    prev_unwrapped = theta_in;
    theta_f        = theta_in;
    prev_theta_f   = theta_in;
    omega_f        = 0;
    initialised    = true;
    omega = 0; theta_unwrapped = theta_in;
    theta_filtered = theta_in; omega_raw = 0;
    return
end

% ---- 1. unwrap only if the source itself wraps --------------------------
if enable_unwrap
    d = theta_in - prev_raw;
    if d > wrap_period/2
        d = d - wrap_period;
    elseif d < -wrap_period/2
        d = d + wrap_period;
    end
    theta_unwrapped = prev_unwrapped + d;
else
    theta_unwrapped = theta_in;   % already an accumulated position
end

% ---- 2. causal first-order low-pass filter on the angle ------------------
alpha_theta = exp(-2*pi*fc_theta*Ts);
theta_f = alpha_theta*theta_f + (1 - alpha_theta)*theta_unwrapped;

% ---- 3. discrete backward difference of the filtered angle ---------------
omega_raw = (theta_f - prev_theta_f) / Ts;

% ---- 4. optional light low-pass filter on the velocity -------------------
if enable_omega_filter
    alpha_omega = exp(-2*pi*fc_omega*Ts);
    omega_f = alpha_omega*omega_f + (1 - alpha_omega)*omega_raw;
else
    omega_f = omega_raw;
end

% ---- state update ---------------------------------------------------------
prev_raw       = theta_in;
prev_unwrapped = theta_unwrapped;
prev_theta_f   = theta_f;
omega          = omega_f;
theta_filtered = theta_f;
end
