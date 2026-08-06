%% MLight-Handover Step 1: FINAL CORRECTED VERSION
clear; close all; clc;

fprintf('=== MLIGHT-HANDOVER: STEP 1 (FINAL CORRECTED) ===\n');
fprintf('Date: %s\n', datestr(now));
fprintf('\n');

%% Constants
R_earth = 6371e3;
c = 3e8;
f_carrier = 2e9;
altitude = 500e3;
GM = 3.986004418e14;
orbit_radius = R_earth + altitude;
orbital_speed = sqrt(GM / orbit_radius);

fprintf('PHYSICS:\n');
fprintf('  Orbital speed: %.2f km/s\n', orbital_speed/1000);
fprintf('  Max Doppler: %.1f kHz\n', (orbital_speed*f_carrier/c)/1000);
fprintf('\n');

%% Place UE at 20.5°N, 85.8°E (Cuttack)
ue_lat = 20.5 * pi/180;
ue_lon = 85.8 * pi/180;
ue_pos = [R_earth*cos(ue_lat)*cos(ue_lon), ...
          R_earth*cos(ue_lat)*sin(ue_lon), ...
          R_earth*sin(ue_lat)];

fprintf('UE position: (%.1f°N, %.1f°E)\n', 20.5, 85.8);

%% Satellite orbit parameters
inc = 53 * pi/180;  % inclination

% For a satellite to pass over the UE, its orbit must cross that latitude
% We'll set initial position so satellite is at same longitude as UE at t=0

% Time array: 10 minutes (600 seconds) of satellite pass
t = 0:600;
num_steps = length(t);

% Pre-allocate
doppler = zeros(num_steps, 1);
delay = zeros(num_steps, 1);
elevation = zeros(num_steps, 1);
distance = zeros(num_steps, 1);

% Simulate satellite passing over UE
% At t=0, satellite is at 500km altitude directly above UE
% Initial position: same lat/lon as UE, at altitude
% Convert lat/lon to ECEF with altitude
sat_pos0 = [(R_earth+altitude)*cos(ue_lat)*cos(ue_lon), ...
            (R_earth+altitude)*cos(ue_lat)*sin(ue_lon), ...
            (R_earth+altitude)*sin(ue_lat)];

% Satellite velocity at this point (tangential to orbit)
% For a circular orbit, velocity is perpendicular to position vector
% At the equator crossing, velocity is mostly Eastward
% We need velocity vector that maintains circular orbit

% Position magnitude
r0 = norm(sat_pos0);
% Velocity magnitude for circular orbit
v_mag = orbital_speed;

% Velocity direction: perpendicular to position and in orbital plane
% For an orbit with inclination inc, at the ascending node
% We'll simplify: velocity is purely Eastward at this point
% This gives a polar orbit approximation
sat_vel0 = [0, v_mag, 0];  % Eastward velocity

fprintf('\nSimulating 10-minute satellite pass...\n');

for i = 1:num_steps
    % Simple linear motion (small time approximation)
    sat_pos = sat_pos0 + sat_vel0 * t(i);
    
    % Range to UE
    dx = sat_pos(1) - ue_pos(1);
    dy = sat_pos(2) - ue_pos(2);
    dz = sat_pos(3) - ue_pos(3);
    dist = sqrt(dx^2 + dy^2 + dz^2);
    distance(i) = dist;
    
    % One-way delay
    delay(i) = dist / c;
    
    % Elevation angle
    % Vector from Earth center to UE
    ue_norm = norm(ue_pos);
    % Angle between UE position and satellite direction
    dot_ue_sat = ue_pos(1)*dx + ue_pos(2)*dy + ue_pos(3)*dz;
    cos_angle = dot_ue_sat / (ue_norm * dist);
    if cos_angle > 1, cos_angle = 1; end
    if cos_angle < -1, cos_angle = -1; end
    angle_from_zenith = acos(cos_angle) * 180/pi;
    elevation(i) = 90 - angle_from_zenith;
    
    % Radial velocity
    if dist > 0
        ux = dx / dist;
        uy = dy / dist;
        uz = dz / dist;
        v_rel = sat_vel0(1)*ux + sat_vel0(2)*uy + sat_vel0(3)*uz;
        doppler(i) = (v_rel * f_carrier) / c;
    else
        doppler(i) = 0;
    end
end

%% Display results for this pass
fprintf('\n=== 10-MINUTE SATELLITE PASS RESULTS ===\n');
fprintf('Max Doppler: %.1f Hz (%.2f kHz)\n', max(abs(doppler)), max(abs(doppler))/1000);
fprintf('Min delay: %.2f ms\n', min(delay)*1000);
fprintf('Max delay: %.2f ms\n', max(delay)*1000);
fprintf('Max elevation: %.1f degrees\n', max(elevation));

% Find when satellite is above 10° elevation
above_threshold = find(elevation > 10);
if ~isempty(above_threshold)
    visible_duration = length(above_threshold);  % seconds
    fprintf('Visible duration (elevation > 10°): %.1f minutes\n', visible_duration/60);
end

%% Plot results
figure('Position', [100, 100, 1000, 800]);

subplot(3,1,1);
plot(t/60, doppler/1000, 'b-', 'LineWidth', 1.5);
xlabel('Time (minutes)'); ylabel('Doppler (kHz)');
title(sprintf('Doppler Shift (Max: %.2f kHz)', max(abs(doppler))/1000));
grid on;
xlim([0, 10]);

subplot(3,1,2);
plot(t/60, delay*1000, 'r-', 'LineWidth', 1.5);
xlabel('Time (minutes)'); ylabel('Delay (ms)');
title(sprintf('Propagation Delay (Min: %.2f ms, Max: %.2f ms)', min(delay)*1000, max(delay)*1000));
grid on;
xlim([0, 10]);

subplot(3,1,3);
plot(t/60, elevation, 'g-', 'LineWidth', 1.5);
xlabel('Time (minutes)'); ylabel('Elevation (degrees)');
title('Elevation Angle');
yline(10, 'r--', 'Handover Threshold');
grid on;
xlim([0, 10]);
ylim([-10, 100]);

title('MLight-Handover: Single Satellite Pass (500 km altitude, S-band)', 'FontSize', 14);

%% Save results
saveas(gcf, 'satellite_pass_results.png');
fprintf('\nPlot saved: satellite_pass_results.png\n');

%% Compare with abstract claims
fprintf('\n========================================\n');
fprintf('COMPARISON WITH ABSTRACT CLAIMS\n');
fprintf('========================================\n');

actual_doppler_khz = max(abs(doppler))/1000;
actual_min_delay_ms = min(delay)*1000;
actual_max_delay_ms = max(delay)*1000;
visible_minutes = visible_duration/60;

fprintf('\n1. Doppler 50.7 kHz: ACTUAL %.2f kHz ', actual_doppler_khz);
if actual_doppler_khz >= 48 && actual_doppler_khz <= 53
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (need 50.7, got %.2f)\n', actual_doppler_khz);
end

fprintf('2. Delay 1-13 ms: ACTUAL %.1f-%.1f ms ', actual_min_delay_ms, actual_max_delay_ms);
if actual_min_delay_ms <= 2 && actual_max_delay_ms >= 12
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (need 1-13, got %.1f-%.1f)\n', actual_min_delay_ms, actual_max_delay_ms);
end

fprintf('3. Handover every 4-7 min: ACTUAL visible window %.1f min ', visible_minutes);
if visible_minutes >= 4 && visible_minutes <= 7
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (need 4-7, got %.1f)\n', visible_minutes);
end

%% Now with realistic orbit (circular motion)
fprintf('\n=== REALISTIC CIRCULAR ORBIT SIMULATION ===\n');

% For a realistic orbit, satellite moves in a circle
% At t=0, satellite at (latitude, longitude) = (0°, 85.8°E)
% Then it moves Eastward in its orbit

% Convert 85.8°E to radians
initial_lon = 85.8 * pi/180;
initial_lat = 0;  % Start at equator

% Position at t=0
sat_pos_real = [(R_earth+altitude)*cos(initial_lat)*cos(initial_lon), ...
                (R_earth+altitude)*cos(initial_lat)*sin(initial_lon), ...
                (R_earth+altitude)*sin(initial_lat)];

% Angular velocity (rad/s)
omega = orbital_speed / orbit_radius;

% Time array (full orbit: 90 minutes)
t_orbit = 0:5400;
doppler_orbit = zeros(length(t_orbit), 1);
delay_orbit = zeros(length(t_orbit), 1);
elev_orbit = zeros(length(t_orbit), 1);

for i = 1:length(t_orbit)
    % Satellite moves Eastward (increasing longitude)
    current_lon = initial_lon + omega * t_orbit(i);
    sat_pos = [(R_earth+altitude)*cos(initial_lat)*cos(current_lon), ...
               (R_earth+altitude)*cos(initial_lat)*sin(current_lon), ...
               (R_earth+altitude)*sin(initial_lat)];
    
    % Range to UE (at 20.5°N, 85.8°E)
    dx = sat_pos(1) - ue_pos(1);
    dy = sat_pos(2) - ue_pos(2);
    dz = sat_pos(3) - ue_pos(3);
    dist = sqrt(dx^2 + dy^2 + dz^2);
    
    delay_orbit(i) = dist / c;
    
    % Elevation
    ue_norm = norm(ue_pos);
    dot_ue_sat = ue_pos(1)*dx + ue_pos(2)*dy + ue_pos(3)*dz;
    cos_angle = dot_ue_sat / (ue_norm * dist);
    if cos_angle > 1, cos_angle = 1; end
    if cos_angle < -1, cos_angle = -1; end
    elev_orbit(i) = 90 - acos(cos_angle)*180/pi;
    
    % Velocity (tangential)
    vx = -orbital_speed * sin(current_lon);
    vy = orbital_speed * cos(current_lon);
    vz = 0;
    
    % Radial velocity
    ux = dx / dist;
    uy = dy / dist;
    uz = dz / dist;
    v_rel = vx*ux + vy*uy + vz*uz;
    doppler_orbit(i) = (v_rel * f_carrier) / c;
end

fprintf('Max Doppler: %.1f Hz (%.2f kHz)\n', max(abs(doppler_orbit)), max(abs(doppler_orbit))/1000);
fprintf('Delay range: %.2f - %.2f ms\n', min(delay_orbit)*1000, max(delay_orbit)*1000);

% Find visible periods
visible = find(elev_orbit > 10);
if ~isempty(visible)
    visible_duration_orbit = length(visible);
    fprintf('Visible duration per pass: %.1f minutes\n', visible_duration_orbit/60);
end

fprintf('\n========================================\n');
fprintf('STEP 1 COMPLETE\n');
fprintf('========================================\n');
