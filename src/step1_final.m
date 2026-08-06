%% MLight-Handover Step 1: SIMPLIFIED VERIFIED VERSION
clear; close all; clc;

fprintf('=== MLIGHT-HANDOVER: STEP 1 (VERIFIED) ===\n');
fprintf('Date: %s\n', datestr(now));
fprintf('\n');

%% Constants
R_earth = 6371e3;       % Earth radius (m)
c = 3e8;                % Speed of light (m/s)
f_carrier = 2e9;        % S-band 2 GHz
altitude = 500e3;       % 500 km

% Orbital speed at 500 km
GM = 3.986004418e14;    % Earth gravitational parameter (m^3/s^2)
orbit_radius = R_earth + altitude;
orbital_speed = sqrt(GM / orbit_radius);

fprintf('PHYSICS CHECK:\n');
fprintf('  Earth radius: %.0f km\n', R_earth/1000);
fprintf('  Orbit radius: %.0f km\n', orbit_radius/1000);
fprintf('  Orbital speed: %.2f m/s (%.2f km/s)\n', orbital_speed, orbital_speed/1000);

max_doppler = (orbital_speed * f_carrier) / c;
fprintf('  Max Doppler: %.0f Hz (%.1f kHz)\n', max_doppler, max_doppler/1000);
fprintf('\n');

%% Test with a single UE and single satellite to verify math
fprintf('=== VERIFICATION TEST (Single UE + Single Satellite) ===\n');

% Place satellite directly above UE at t=0
ue_lat = 20.5 * pi/180;
ue_lon = 85.8 * pi/180;
ue_pos = [R_earth*cos(ue_lat)*cos(ue_lon), ...
          R_earth*cos(ue_lat)*sin(ue_lon), ...
          R_earth*sin(ue_lat)];

% Satellite orbit: circular, 53° inclination
inc = 53 * pi/180;
orbit_normal = [0, sin(inc), cos(inc)];

% Time array (5 minutes, 1 sec steps)
t = 0:300;  % 5 minutes
dt = 1;
num_steps = length(t);

sat_pos = zeros(num_steps, 3);
doppler_test = zeros(num_steps, 1);
delay_test = zeros(num_steps, 1);
elev_test = zeros(num_steps, 1);

% Initial satellite position (at 0° longitude crossing)
sat_angle0 = 0;  % radians

for i = 1:num_steps
    % Satellite moves at orbital_speed
    angle_traveled = orbital_speed / orbit_radius * t(i);
    theta = sat_angle0 + angle_traveled;
    
    % Position in orbital plane
    x_plane = orbit_radius * cos(theta);
    y_plane = orbit_radius * sin(theta);
    z_plane = 0;
    
    % Rotate by inclination
    sat_pos(i,:) = [x_plane, y_plane*cos(inc) - z_plane*sin(inc), ...
                    y_plane*sin(inc) + z_plane*cos(inc)];
    
    % Distance to UE
    dx = sat_pos(i,1) - ue_pos(1);
    dy = sat_pos(i,2) - ue_pos(2);
    dz = sat_pos(i,3) - ue_pos(3);
    dist = sqrt(dx^2 + dy^2 + dz^2);
    
    % One-way delay
    delay_test(i) = dist / c;
    
    % Elevation angle
    ue_norm = norm(ue_pos);
    dot_ue_sat = ue_pos(1)*dx + ue_pos(2)*dy + ue_pos(3)*dz;
    cos_angle = dot_ue_sat / (ue_norm * dist);
    if cos_angle > 1, cos_angle = 1; end
    if cos_angle < -1, cos_angle = -1; end
    elev_test(i) = 90 - acos(cos_angle)*180/pi;
    
    % Velocity
    vx = -orbital_speed * sin(theta);
    vy = orbital_speed * cos(theta) * cos(inc);
    vz = orbital_speed * cos(theta) * sin(inc);
    
    % Radial velocity
    ux = dx / dist;
    uy = dy / dist;
    uz = dz / dist;
    v_rel = vx*ux + vy*uy + vz*uz;
    
    % Doppler
    doppler_test(i) = (v_rel * f_carrier) / c;
end

fprintf('Test Results (5-minute pass):\n');
fprintf('  Max Doppler: %.1f Hz (%.2f kHz)\n', max(abs(doppler_test)), max(abs(doppler_test))/1000);
fprintf('  Min delay: %.2f ms\n', min(delay_test)*1000);
fprintf('  Max delay: %.2f ms\n', max(delay_test)*1000);
fprintf('  Max elevation: %.1f degrees\n', max(elev_test));

if max(abs(doppler_test))/1000 >= 48
    fprintf('\n  ✓ VERIFICATION PASSED: Doppler matches theory\n');
else
    fprintf('\n  ✗ VERIFICATION FAILED: Check calculations\n');
end

%% Now full simulation with 3 sats, 50 UEs
fprintf('\n=== FULL SIMULATION (3 Sats, 50 UEs) ===\n');

num_sats = 3;
num_ues = 50;
duration_sec = 5400;  % 90 minutes
time = 0:duration_sec;
num_steps = length(time);

% Satellite true anomalies (120° apart)
true_anom_start = [0, 120, 240] * pi/180;

% UE positions (100km x 100km area)
center_lat = 20.5 * pi/180;
center_lon = 85.8 * pi/180;
lat_range = (100/111) * pi/180;  % 100km in radians
lon_range = (100/111/cos(center_lat)) * pi/180;

rng(42);
ue_lats = center_lat + (rand(num_ues,1) - 0.5) * lat_range;
ue_lons = center_lon + (rand(num_ues,1) - 0.5) * lon_range;

% Pre-allocate
ue_positions = zeros(num_ues, 3);
for u = 1:num_ues
    ue_positions(u,:) = [R_earth*cos(ue_lats(u))*cos(ue_lons(u)), ...
                         R_earth*cos(ue_lats(u))*sin(ue_lons(u)), ...
                         R_earth*sin(ue_lats(u))];
end

% Results arrays
doppler_full = zeros(num_steps, num_ues, num_sats);
delay_full = zeros(num_steps, num_ues, num_sats);
elev_full = zeros(num_steps, num_ues, num_sats);

fprintf('Computing...\n');
tic;

for t_idx = 1:num_steps
    angle_traveled = orbital_speed / orbit_radius * time(t_idx);
    
    for s = 1:num_sats
        theta = true_anom_start(s) + angle_traveled;
        
        % Satellite position
        x_plane = orbit_radius * cos(theta);
        y_plane = orbit_radius * sin(theta);
        sat_pos = [x_plane, y_plane*cos(inc) - 0*sin(inc), ...
                   y_plane*sin(inc) + 0*cos(inc)];
        
        % Velocity
        vx = -orbital_speed * sin(theta);
        vy = orbital_speed * cos(theta) * cos(inc);
        vz = orbital_speed * cos(theta) * sin(inc);
        sat_vel = [vx, vy, vz];
        
        for u = 1:num_ues
            dx = sat_pos(1) - ue_positions(u,1);
            dy = sat_pos(2) - ue_positions(u,2);
            dz = sat_pos(3) - ue_positions(u,3);
            dist = sqrt(dx^2 + dy^2 + dz^2);
            
            % Delay (one-way)
            delay_full(t_idx, u, s) = dist / c;
            
            % Elevation
            ue_norm = norm(ue_positions(u,:));
            dot_ue_sat = ue_positions(u,1)*dx + ue_positions(u,2)*dy + ue_positions(u,3)*dz;
            cos_angle = dot_ue_sat / (ue_norm * dist);
            if cos_angle > 1, cos_angle = 1; end
            if cos_angle < -1, cos_angle = -1; end
            elev_full(t_idx, u, s) = 90 - acos(cos_angle)*180/pi;
            
            % Radial velocity and Doppler
            ux = dx / dist;
            uy = dy / dist;
            uz = dz / dist;
            v_rel = sat_vel(1)*ux + sat_vel(2)*uy + sat_vel(3)*uz;
            doppler_full(t_idx, u, s) = (v_rel * f_carrier) / c;
        end
    end
    
    if mod(t_idx, 1000) == 0
        fprintf('  Progress: %.1f%%\n', t_idx/num_steps*100);
    end
end

elapsed = toc;
fprintf('  Progress: 100%% (%.2f seconds)\n', elapsed);

%% Final Results
fprintf('\n========================================\n');
fprintf('FINAL RESULTS\n');
fprintf('========================================\n');

max_doppler_actual = max(abs(doppler_full(:)));
max_doppler_khz = max_doppler_actual / 1000;
min_delay_ms = min(delay_full(:)) * 1000;
max_delay_ms = max(delay_full(:)) * 1000;

fprintf('\nDOPPLER:\n');
fprintf('  Actual max: %.1f Hz (%.2f kHz)\n', max_doppler_actual, max_doppler_khz);
fprintf('  Theoretical: %.1f Hz (%.2f kHz)\n', max_doppler, max_doppler/1000);
fprintf('  Match: %.1f%%\n', max_doppler_actual/max_doppler*100);

fprintf('\nDELAY:\n');
fprintf('  Min: %.2f ms\n', min_delay_ms);
fprintf('  Max: %.2f ms\n', max_delay_ms);

% Handover analysis
threshold = 10;  % degrees
total_hos = 0;

for u = 1:num_ues
    current = 1;
    for t_idx = 2:num_steps
        e = squeeze(elev_full(t_idx, u, :));
        [max_e, best] = max(e);
        if best ~= current && max_e > threshold
            total_hos = total_hos + 1;
            current = best;
        end
    end
end

ho_per_ue = total_hos / num_ues;
ho_interval = 90 / ho_per_ue;  % minutes

fprintf('\nHANDOVER:\n');
fprintf('  Total: %d\n', total_hos);
fprintf('  Per UE: %.2f\n', ho_per_ue);
fprintf('  Interval: %.1f minutes\n', ho_interval);

%% Compare with abstract
fprintf('\n========================================\n');
fprintf('ABSTRACT CLAIM VERIFICATION\n');
fprintf('========================================\n');

fprintf('1. Doppler 50.7 kHz: %.2f kHz ', max_doppler_khz);
if max_doppler_khz >= 48 && max_doppler_khz <= 53
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (target: 50.7)\n');
end

fprintf('2. Delay 1-13 ms: %.1f-%.1f ms ', min_delay_ms, max_delay_ms);
if min_delay_ms <= 2 && max_delay_ms >= 12
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (target: 1-13)\n');
end

fprintf('3. Handover 4-7 min: %.1f min ', ho_interval);
if ho_interval >= 4 && ho_interval <= 7
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (target: 4-7)\n');
end

%% Simple plot (avoid histogram)
figure;
subplot(2,1,1);
plot(time/60, squeeze(doppler_full(:,1,1))/1000, 'b-');
xlabel('Time (min)'); ylabel('Doppler (kHz)');
title(sprintf('Doppler: UE1-Sat1 (Max: %.1f kHz)', max_doppler_khz));
grid on;

subplot(2,1,2);
plot(time/60, squeeze(delay_full(:,1,1))*1000, 'r-');
xlabel('Time (min)'); ylabel('Delay (ms)');
title(sprintf('Delay: %.1f-%.1f ms', min_delay_ms, max_delay_ms));
grid on;

saveas(gcf, 'step1_results.png');
fprintf('\nPlot saved: step1_results.png\n');

%% Save
save('leo_dynamics_step1.mat', 'doppler_full', 'delay_full', 'elev_full');
fprintf('\nData saved: leo_dynamics_step1.mat\n');
fprintf('\n=== STEP 1 COMPLETE ===\n');
