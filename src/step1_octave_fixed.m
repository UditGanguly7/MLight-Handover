%% MLight-Handover Step 1: CORRECTED PHYSICS
clear; close all; clc;

fprintf('=== MLIGHT-HANDOVER: STEP 1 (CORRECTED) ===\n');
fprintf('Date: %s\n', datestr(now));
fprintf('\n');

%% Constants
R_earth = 6371e3;       % Earth radius (m)
c = 3e8;                % Speed of light (m/s)
f_carrier = 2e9;        % S-band frequency (Hz)
altitude = 500e3;       % 500 km

% Orbital speed (circular orbit)
GM = 3.986e14;          % Earth gravitational parameter (m^3/s^2)
orbit_radius = R_earth + altitude;
orbital_speed = sqrt(GM / orbit_radius);

fprintf('ORBITAL PARAMETERS:\n');
fprintf('  Altitude: %.0f km\n', altitude/1000);
fprintf('  Orbital speed: %.2f km/s\n', orbital_speed/1000);

max_doppler_theoretical = (orbital_speed * f_carrier) / c;
fprintf('  Theoretical max Doppler: %.1f kHz\n', max_doppler_theoretical/1000);
fprintf('\n');

%% Simulation parameters
num_sats = 3;
num_ues = 50;
duration_min = 90;          % 90 minutes
time_step = 1;              % 1 second
num_steps = duration_min * 60 + 1;

fprintf('SIMULATION SETUP:\n');
fprintf('  Satellites: %d\n', num_sats);
fprintf('  User Equipment: %d\n', num_ues);
fprintf('  Duration: %d minutes\n', duration_min);
fprintf('  Time steps: %d\n', num_steps);
fprintf('\n');

%% Satellite orbits
inclination = 53;           % degrees
true_anomaly_start = [0, 120, 240];

sat_pos = zeros(num_steps, 3, num_sats);
sat_vel = zeros(num_steps, 3, num_sats);

fprintf('Computing satellite orbits...\n');

inc_rad = inclination * pi/180;
R_x = [1, 0, 0;
       0, cos(inc_rad), -sin(inc_rad);
       0, sin(inc_rad), cos(inc_rad)];

for t = 1:num_steps
    time_sec = (t-1) * time_step;
    angle_rad = orbital_speed / orbit_radius * time_sec;
    
    for s = 1:num_sats
        theta_rad = (true_anomaly_start(s) * pi/180) + angle_rad;
        
        % Position
        x_orbit = orbit_radius * cos(theta_rad);
        y_orbit = orbit_radius * sin(theta_rad);
        z_orbit = 0;
        pos_plane = [x_orbit; y_orbit; z_orbit];
        sat_pos(t,:,s) = (R_x * pos_plane)';
        
        % Velocity (tangential)
        vx_orbit = -orbital_speed * sin(theta_rad);
        vy_orbit = orbital_speed * cos(theta_rad);
        vz_orbit = 0;
        vel_plane = [vx_orbit; vy_orbit; vz_orbit];
        sat_vel(t,:,s) = (R_x * vel_plane)';
    end
    
    if mod(t, 1000) == 0
        fprintf('  Progress: %.1f%%\n', t/num_steps*100);
    end
end
fprintf('  Progress: 100%%\n');

%% Generate UE positions (100km x 100km area)
fprintf('\nGenerating UE positions...\n');
center_lat = 20.5;      % degrees
center_lon = 85.8;      % degrees

lat_range_deg = 0.9;
lon_range_deg = 0.9;

rng(42);
ue_lat_deg = center_lat + (rand(num_ues,1) - 0.5) * lat_range_deg;
ue_lon_deg = center_lon + (rand(num_ues,1) - 0.5) * lon_range_deg;

fprintf('  UE latitude range: %.3f to %.3f\n', min(ue_lat_deg), max(ue_lat_deg));
fprintf('  UE longitude range: %.3f to %.3f\n', min(ue_lon_deg), max(ue_lon_deg));

%% Convert UE to ECEF
ue_pos = zeros(num_ues, 3);
for u = 1:num_ues
    lat_rad = ue_lat_deg(u) * pi/180;
    lon_rad = ue_lon_deg(u) * pi/180;
    
    ue_pos(u,1) = R_earth * cos(lat_rad) * cos(lon_rad);
    ue_pos(u,2) = R_earth * cos(lat_rad) * sin(lon_rad);
    ue_pos(u,3) = R_earth * sin(lat_rad);
end

%% Compute Doppler, delay, elevation
fprintf('\nComputing propagation effects...\n');
fprintf('  Total calculations: %d\n', num_steps * num_ues * num_sats);
fprintf('  Estimated time: 30-60 seconds\n');

doppler = zeros(num_steps, num_ues, num_sats);
delay = zeros(num_steps, num_ues, num_sats);
elevation = zeros(num_steps, num_ues, num_sats);

tic;

for t = 1:num_steps
    for u = 1:num_ues
        for s = 1:num_sats
            % Range vector and distance
            dx = sat_pos(t,1,s) - ue_pos(u,1);
            dy = sat_pos(t,2,s) - ue_pos(u,2);
            dz = sat_pos(t,3,s) - ue_pos(u,3);
            distance = sqrt(dx*dx + dy*dy + dz*dz);
            
            % ONE-WAY delay (not round trip) - 3GPP TR 38.821
            delay(t,u,s) = distance / c;
            
            % Radial velocity using actual velocity vector
            % Unit vector from UE to satellite
            if distance > 0
                ux = dx / distance;
                uy = dy / distance;
                uz = dz / distance;
            else
                ux = 0; uy = 0; uz = 0;
            end
            
            % Project satellite velocity onto line-of-sight
            v_rel = sat_vel(t,1,s)*ux + sat_vel(t,2,s)*uy + sat_vel(t,3,s)*uz;
            
            % Doppler shift (positive when approaching)
            doppler(t,u,s) = (v_rel * f_carrier) / c;
            
            % Elevation angle (corrected)
            % UE position vector from Earth center
            ue_norm = sqrt(ue_pos(u,1)^2 + ue_pos(u,2)^2 + ue_pos(u,3)^2);
            
            % Vector from UE to satellite
            sat_vec_x = dx;
            sat_vec_y = dy;
            sat_vec_z = dz;
            sat_vec_norm = distance;
            
            % Angle between UE's radial vector and satellite direction
            % cos(angle) = (ue_pos · sat_vec) / (|ue_pos| * |sat_vec|)
            dot_ue_sat = ue_pos(u,1)*sat_vec_x + ue_pos(u,2)*sat_vec_y + ue_pos(u,3)*sat_vec_z;
            cos_angle = dot_ue_sat / (ue_norm * sat_vec_norm);
            if cos_angle > 1, cos_angle = 1; end
            if cos_angle < -1, cos_angle = -1; end
            
            % Elevation = 90° - angle between UE position and satellite direction
            angle_deg = acos(cos_angle) * 180/pi;
            elevation(t,u,s) = 90 - angle_deg;
        end
    end
    
    if mod(t, 500) == 0
        fprintf('  Progress: %.1f%%\n', t/num_steps*100);
    end
end

elapsed = toc;
fprintf('  Progress: 100%% (%.2f seconds)\n', elapsed);

%% Results
fprintf('\n========================================\n');
fprintf('RESULTS\n');
fprintf('========================================\n');

% Doppler
max_doppler_hz = max(abs(doppler(:)));
max_doppler_khz = max_doppler_hz / 1000;
min_doppler_hz = min(doppler(:));
fprintf('\nDOPPLER:\n');
fprintf('  Maximum positive: %.1f Hz (%.2f kHz)\n', max(doppler(:)), max(doppler(:))/1000);
fprintf('  Maximum negative: %.1f Hz (%.2f kHz)\n', min(doppler(:)), min(doppler(:))/1000);
fprintf('  Maximum |Doppler|: %.1f Hz (%.2f kHz)\n', max_doppler_hz, max_doppler_khz);
fprintf('  Theoretical max: %.1f Hz (%.2f kHz)\n', max_doppler_theoretical, max_doppler_theoretical/1000);
fprintf('  Match: %.1f%%\n', max_doppler_hz / max_doppler_theoretical * 100);

% Delay (now one-way)
min_delay_ms = min(delay(:)) * 1000;
max_delay_ms = max(delay(:)) * 1000;
fprintf('\nDELAY (one-way, 3GPP TR 38.821):\n');
fprintf('  Minimum: %.2f ms\n', min_delay_ms);
fprintf('  Maximum: %.2f ms\n', max_delay_ms);
fprintf('  Range: %.1f - %.1f ms\n', min_delay_ms, max_delay_ms);

% Handover
threshold_elev = 10;  % degrees
total_handovers = 0;
handover_log = [];

for u = 1:num_ues
    current_sat = 1;
    for t = 2:num_steps
        e1 = elevation(t,u,1);
        e2 = elevation(t,u,2);
        e3 = elevation(t,u,3);
        
        [max_elev, best_sat] = max([e1, e2, e3]);
        
        if best_sat ~= current_sat && max_elev > threshold_elev
            total_handovers = total_handovers + 1;
            handover_log = [handover_log; u, t, current_sat, best_sat, max_elev];
            current_sat = best_sat;
        end
    end
end

handovers_per_ue = total_handovers / num_ues;
handover_interval_min = duration_min / handovers_per_ue;

fprintf('\nHANDOVER:\n');
fprintf('  Elevation threshold: %.0f°\n', threshold_elev);
fprintf('  Total handovers: %d\n', total_handovers);
fprintf('  Handovers per UE: %.2f\n', handovers_per_ue);
fprintf('  Average interval: %.1f minutes\n', handover_interval_min);

%% Comparison
fprintf('\n========================================\n');
fprintf('COMPARISON WITH ABSTRACT CLAIMS\n');
fprintf('========================================\n');

fprintf('\n1. Doppler 50.7 kHz: ACTUAL %.2f kHz ', max_doppler_khz);
if max_doppler_khz >= 48 && max_doppler_khz <= 53
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (expected 50.7, got %.2f)\n', max_doppler_khz);
end

fprintf('2. Delay 1-13 ms: ACTUAL %.1f-%.1f ms ', min_delay_ms, max_delay_ms);
if min_delay_ms <= 2 && max_delay_ms >= 12
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (expected 1-13, got %.1f-%.1f)\n', min_delay_ms, max_delay_ms);
end

fprintf('3. Handover 4-7 min: ACTUAL %.1f min ', handover_interval_min);
if handover_interval_min >= 4 && handover_interval_min <= 7
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (expected 4-7, got %.1f)\n', handover_interval_min);
end

%% Plot sample results
figure(1);
clf;

subplot(2,2,1);
plot((0:num_steps-1)/60, squeeze(doppler(:,1,1))/1000, 'b-', 'LineWidth', 1);
xlabel('Time (minutes)'); ylabel('Doppler (kHz)');
title(sprintf('Doppler: UE1-Sat1 (Max: %.1f kHz)', max_doppler_khz));
grid on;

subplot(2,2,2);
plot((0:num_steps-1)/60, squeeze(delay(:,1,1))*1000, 'r-', 'LineWidth', 1);
xlabel('Time (minutes)'); ylabel('Delay (ms)');
title(sprintf('Delay: %.1f-%.1f ms', min_delay_ms, max_delay_ms));
grid on;

subplot(2,2,3);
plot((0:num_steps-1)/60, squeeze(elevation(:,1,:)), 'LineWidth', 1);
xlabel('Time (minutes)'); ylabel('Elevation (deg)');
title('Elevation Angles (UE1)');
legend('Sat1', 'Sat2', 'Sat3');
yline(threshold_elev, 'r--', 'Handover Threshold');
grid on;

subplot(2,2,4);
histogram(abs(doppler(:))/1000, 30);
xlabel('|Doppler| (kHz)'); ylabel('Count');
title(sprintf('Doppler Distribution (Mean: %.1f kHz)', mean(abs(doppler(:)))/1000));
grid on;

sgtitle('MLight-Handover: Step 1 Results');

saveas(gcf, 'step1_results.png');
fprintf('\nSaved plot: step1_results.png\n');

%% Save data
save('leo_dynamics_step1.mat', 'doppler', 'delay', 'elevation', ...
     'max_doppler_khz', 'min_delay_ms', 'max_delay_ms', 'handover_interval_min');

fprintf('\nSaved: leo_dynamics_step1.mat\n');
fprintf('\n=== STEP 1 COMPLETE ===\n');
