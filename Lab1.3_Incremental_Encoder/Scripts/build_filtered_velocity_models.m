function build_filtered_velocity_models()
%BUILD_FILTERED_VELOCITY_MODELS Edit the existing encoder models IN PLACE with
% the filtered-angle angular-velocity pipeline and remove the superseded
% (old, unused) velocity blocks.
%
% Edited files (in this folder):
%   sensorExpoler_Encoder_Bourns.slx
%   sensorExpoler_Encoder_AMT_103V.slx
% Backups (pristine originals, created once on the first run):
%   sensorExpoler_Encoder_Bourns_backup_original.slx
%   sensorExpoler_Encoder_AMT_103V_backup_original.slx
%
% The script is idempotent: it restores the pristine backup over the working
% model and re-applies the edit, so it can be run repeatedly.
%
% Per path (X1/X2/X4) the script:
%   1. deletes the old velocity path (Count2Speed*, Discrete Derivative*) and
%      its displays (Display_dtheta*, Display_omega_original_*) -- these were
%      diagnostic-only after the rewrite and are now removed completely;
%   2. adds the masked subsystem Angle_to_AngularVelocity_<tag>:
%        Count2Rad -> [unwrap, disabled] -> [1st-order LPF @ fc_theta]
%                  -> [(theta_f[k]-theta_f[k-1])/Ts]
%                  -> [light LPF @ fc_omega, bypassable] -> omega_final
%   3. routes omega_final to the existing Display_omega* (production consumer);
%   4. adds Display_omega_raw_<tag> and logs the diagnostics.
%
% See the "Filtered angular velocity" section of ENCODER_SIMULINK_NOTES.md for
% parameter justification and validation results.

here = fileparts(mfilename('fullpath'));
simDir = fullfile(fileparts(here), 'Simulink');
addpath(here);

% {tag, Count2Rad, Count2Speed(legacy), Display_omega, DiscreteDerivative(legacy), Display_dtheta(legacy), fc_theta, fc_omega}
models = {
    'sensorExpoler_Encoder_Bourns', { ...
        {'X1','Count2Rad', 'Count2Speed', 'Display_omega',    'Discrete Derivative', 'Display_dtheta',    0.5,  5};
        {'X2','Count2Rad1','Count2Speed1','Display_omega X2', 'Discrete Derivative1','Display_dtheta X2', 1.0,  5};
        {'X4','Count2Rad2','Count2Speed2','Display_omega X4', 'Discrete Derivative2','Display_dtheta X4', 2.0,  5}};
    'sensorExpoler_Encoder_AMT_103V', { ...
        {'X1','Count2Rad', 'Count2Speed', 'Display_omega',    'Discrete Derivative', 'Display_dtheta',     5,  10};
        {'X2','Count2Rad1','Count2Speed1','Display_omega X2', 'Discrete Derivative1','Display_dtheta X2', 10,  20};
        {'X4','Count2Rad2','Count2Speed2','Display_omega X4', 'Discrete Derivative2','Display_dtheta X4', 20,  40}};
};

fcnText = fileread(fullfile(here, 'FilteredAngularVelocity.m'));

for m = 1:size(models,1)
    name = models{m,1};
    paths = models{m,2};
    f   = fullfile(simDir, [name '.slx']);
    bak = fullfile(simDir, [name '_backup_original.slx']);
    assert(isfile(f), 'missing %s', f);
    if ~isfile(bak)
        copyfile(f, bak);
        fprintf('backup   : %s\n', bak);
    end
    if bdIsLoaded(name), close_system(name, 0); end
    copyfile(bak, f);                 % start from the pristine original
    load_system(f);
    fprintf('editing  : %s\n', f);
    for k = 1:numel(paths)
        build_path(name, paths{k}{:}, fcnText);
    end
    try
        set_param(name, 'SimulationCommand', 'update');
        fprintf('  update OK\n');
    catch err
        fprintf('  UPDATE FAILED: %s\n', err.message);
    end
    save_system(name);
    close_system(name, 0);
end
fprintf('done.\n');
end

% ========================================================================
function build_path(mdl, tag, radBlk, speedBlk, dispBlk, ddBlk, dthetaDisp, fcTheta, fcOmega, fcnText)
%BUILD_PATH Rewire one path: remove the legacy velocity blocks, add the
% filtered-angle subsystem, and hand omega_final to the existing display.

sub     = [mdl '/Angle_to_AngularVelocity_' tag];
subName = ['Angle_to_AngularVelocity_' tag];

% ---- 1. remove the superseded velocity / derivative diagnostic path ------
delete_block([mdl '/' speedBlk]);      % Count2Speed*      (old velocity)
delete_block([mdl '/' ddBlk]);         % Discrete Derivative* (old derivative)
delete_block([mdl '/' dthetaDisp]);    % Display_dtheta*   (its display)

% ---- 2. subsystem shell (R2026a creates an empty subsystem) -------------
p  = get_param([mdl '/' dispBlk], 'Position');
yc = (p(2) + p(4)) / 2;
subPos = [1500, yc-60, 1720, yc+60];
add_block('built-in/Subsystem', sub, 'Position', subPos);

% ---- mask: the tunable parameters ---------------------------------------
mask = Simulink.Mask.create(sub);
mask.Description = sprintf(['Filtered angle -> angular velocity (%s).\n' ...
    'theta -> [unwrap] -> [1st-order angle LPF @ fc_theta] -> ' ...
    '[(theta[k]-theta[k-1])/Ts] -> [light velocity LPF @ fc_omega] -> omega.\n' ...
    'State initialised from the first valid sample; output 0 on first sample/reset.'], tag);
mask.addParameter('Type','edit','Name','Ts', ...
    'Prompt','Effective sensor sample time [s]','Value','0.001');
mask.addParameter('Type','edit','Name','fc_theta', ...
    'Prompt','Angle low-pass cutoff [Hz] (0 < fc < 1/(2*Ts))','Value',num2str(fcTheta));
mask.addParameter('Type','edit','Name','fc_omega', ...
    'Prompt','Velocity low-pass cutoff [Hz]','Value',num2str(fcOmega));
mask.addParameter('Type','edit','Name','Enable_velocity_filter', ...
    'Prompt','1 = light velocity LPF on, 0 = bypass','Value','1');
mask.addParameter('Type','edit','Name','Enable_unwrap', ...
    'Prompt','1 = unwrap a wrapped angle, 0 = angle already accumulated','Value','0');
mask.addParameter('Type','edit','Name','Wrap_period', ...
    'Prompt','Wrap period [rad] (2*pi) or [deg] (360)','Value','2*pi');

% ---- inports ------------------------------------------------------------
add_block('built-in/Inport', [sub '/theta_in'], 'Position', [30 30 60 44], 'Port','1');
add_block('built-in/Inport', [sub '/reset'],    'Position', [30 95 60 109], 'Port','2');

% ---- parameter constants (values are mask parameter names) --------------
cPos = [30 150; 30 180; 30 210; 30 240; 30 270; 30 300];
cVal = {'Ts','fc_theta','fc_omega','Enable_velocity_filter','Enable_unwrap','Wrap_period'};
cNam = {'Ts','fc_theta','fc_omega','Enable_velocity_filter','Enable_unwrap','Wrap_period'};
for k = 1:6
    add_block('built-in/Constant', [sub '/' cNam{k}], ...
        'Value', cVal{k}, 'Position', [cPos(k,1) cPos(k,2) cPos(k,1)+100 cPos(k,2)+20]);
end

% ---- the core MATLAB Function block -------------------------------------
add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [sub '/FilteredAngularVelocity'], 'Position', [190 20 340 330]);
rt = sfroot;
ch = rt.find('-isa','Stateflow.EMChart','Path',[sub '/FilteredAngularVelocity']);
assert(numel(ch) == 1, 'EML chart not found in %s', sub);
ch.Script = fcnText;

% ---- outports -----------------------------------------------------------
add_block('built-in/Outport', [sub '/omega_final'],     'Position', [420 30 450 44],  'Port','1');
add_block('built-in/Outport', [sub '/theta_unwrapped'], 'Position', [420 95 450 109], 'Port','2');
add_block('built-in/Outport', [sub '/theta_filtered'],  'Position', [420 160 450 174],'Port','3');
add_block('built-in/Outport', [sub '/omega_raw'],       'Position', [420 225 450 239],'Port','4');

% ---- internal connections ----------------------------------------------
add_line(sub, 'theta_in/1',  'FilteredAngularVelocity/1', 'autorouting','on');
add_line(sub, 'reset/1',     'FilteredAngularVelocity/2', 'autorouting','on');
for k = 1:6
    add_line(sub, [cNam{k} '/1'], sprintf('FilteredAngularVelocity/%d', k+2), 'autorouting','on');
end
add_line(sub, 'FilteredAngularVelocity/1', 'omega_final/1',     'autorouting','on');
add_line(sub, 'FilteredAngularVelocity/2', 'theta_unwrapped/1', 'autorouting','on');
add_line(sub, 'FilteredAngularVelocity/3', 'theta_filtered/1',  'autorouting','on');
add_line(sub, 'FilteredAngularVelocity/4', 'omega_raw/1',       'autorouting','on');

% ---- 3. top level: inputs ----------------------------------------------
add_line(mdl, [radBlk '/1'], [subName '/1'], 'autorouting','on');   % theta_in
add_line(mdl, 'reset/1',     [subName '/2'], 'autorouting','on');   % reset

% ---- 4. production consumer gets the NEW final velocity -----------------
phD = get_param([mdl '/' dispBlk], 'PortHandles');
lhD = get_param(phD.Inport(1), 'Line');
if lhD ~= -1, delete_line(lhD); end          % clear any leftover segment
add_line(mdl, [subName '/1'], [dispBlk '/1'], 'autorouting','on');
set_param([mdl '/' dispBlk], 'Position', [1820 yc-15 1900 yc+25]);

% ---- 5. diagnostic display: velocity before the optional LPF ------------
add_block('built-in/Display', [mdl '/Display_omega_raw_' tag], ...
    'Position', [1820 yc-65 1900 yc-25]);
add_line(mdl, [subName '/4'], ['Display_omega_raw_' tag '/1'], 'autorouting','on');

% ---- 6. logging-only outputs get terminators ----------------------------
add_block('built-in/Terminator', [mdl '/Term_theta_unwrapped_' tag], ...
    'Position', [1790 yc+35 1810 yc+49]);
add_line(mdl, [subName '/2'], ['Term_theta_unwrapped_' tag '/1'], 'autorouting','on');
add_block('built-in/Terminator', [mdl '/Term_theta_filtered_' tag], ...
    'Position', [1790 yc+55 1810 yc+69]);
add_line(mdl, [subName '/3'], ['Term_theta_filtered_' tag '/1'], 'autorouting','on');

% ---- 7. name the diagnostic lines and enable signal logging ------------
% Port DataLogging persists and feeds `logsout` (SignalLogging is on in the
% model config).  The raw angle is the already-named Count2Rad output.
lh = get_param(sub, 'LineHandles');
ph = get_param(sub, 'PortHandles');
outNames = {['omega_final_' tag], ['theta_unwrapped_' tag], ...
            ['theta_filtered_' tag], ['omega_raw_' tag]};
for k = 1:4
    set_param(lh.Outport(k), 'Name', outNames{k});
    set_param(ph.Outport(k), 'DataLogging', 'on');
end
phR = get_param([mdl '/' radBlk], 'PortHandles');
set_param(phR.Outport(1), 'DataLogging', 'on');   % raw angle (theta_rad)

fprintf('  path %s: legacy Count2Speed/Discrete Derivative removed; diagnostics logged; fc_theta=%g Hz, fc_omega=%g Hz\n', ...
    tag, fcTheta, fcOmega);
end
