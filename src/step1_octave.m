%% MLight-Handover Step 1: LEO Geometry (SIMPLIFIED - GUARANTEED TO WORK)
clear; close all; clc;

fprintf('=== MLIGHT-HANDOVER: STEP 1 ===\n');
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

%% Satellite orbits (simplified: circular, 53° inclination)
inclination = 53;           % degrees
true_anomaly_start = [0, 120, 240];  % degrees separation

% Pre-allocate
sat_pos = zeros(num_steps, 3, num_sats);
doppler = zeros(num_steps, num_ues, num_sats);
delay = zeros(num_steps, num_ues, num_sats);
elevation = zeros(num_steps, num_ues, num_sats);

fprintf('Computing satellite orbits...\n');

% Rotation matrix for inclination
inc_rad = inclination * pi/180;
R_x = [1, 0, 0;
       0, cos(inc_rad), -sin(inc_rad);
       0, sin(inc_rad), cos(inc_rad)];

for t = 1:num_steps
    time_sec = (t-1) * time_step;
    angle = orbital_speed / orbit_radius * time_sec;  % radians traveled
    
    for s = 1:num_sats
        % Current true anomaly
        theta_rad = (true_anomaly_start(s) * pi/180) + angle;
        
        % Position in orbital plane
        x_orbit = orbit_radius * cos(theta_rad);
        y_orbit = orbit_radius * sin(theta_rad);
        z_orbit = 0;
        
        % Rotate to ECEF
        pos_plane = [x_orbit; y_orbit; z_orbit];
        sat_pos(t,:,s) = (R_x * pos_plane)';
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

% Convert to radians
center_lat_rad = center_lat * pi/180;
center_lon_rad = center_lon * pi/180;

% 100 km in degrees (approx)
lat_range_deg = 0.9;
lon_range_deg = 0.9;

rng(42);  % For reproducibility
ue_lat_deg = center_lat + (rand(num_ues,1) - 0.5) * lat_range_deg;
ue_lon_deg = center_lon + (rand(num_ues,1) - 0.5) * lon_range_deg;

fprintf('  UE latitude range: %.3f to %.3f\n', min(ue_lat_deg), max(ue_lat_deg));
fprintf('  UE longitude range: %.3f to %.3f\n', min(ue_lon_deg), max(ue_lon_deg));

%% Convert UE to ECEF coordinates
ue_pos = zeros(num_ues, 3);
for u = 1:num_ues
    lat_rad = ue_lat_deg(u) * pi/180;
    lon_rad = ue_lon_deg(u) * pi/180;
    
    ue_pos(u,1) = R_earth * cos(lat_rad) * cos(lon_rad);
    ue_pos(u,2) = R_earth * cos(lat_rad) * sin(lon_rad);
    ue_pos(u,3) = R_earth * sin(lat_rad);
end

%% Compute Doppler, delay, elevation for all pairs
fprintf('\nComputing propagation effects...\n');
fprintf('  Total calculations: %d\n', num_steps * num_ues * num_sats);
fprintf('  Estimated time: 30-60 seconds\n');

tic;

for t = 1:num_steps
    for u = 1:num_ues
        for s = 1:num_sats
            % Range vector and distance
            dx = sat_pos(t,1,s) - ue_pos(u,1);
            dy = sat_pos(t,2,s) - ue_pos(u,2);
            dz = sat_pos(t,3,s) - ue_pos(u,3);
            distance = sqrt(dx*dx + dy*dy + dz*dz);
            
            % Round trip delay
            delay(t,u,s) = 2 * distance / c;
            
            % Radial velocity (using previous time step)
            if t > 1
                dx_prev = sat_pos(t-1,1,s) - ue_pos(u,1);
                dy_prev = sat_pos(t-1,2,s) - ue_pos(u,2);
                dz_prev = sat_pos(t-1,3,s) - ue_pos(u,3);
                dist_prev = sqrt(dx_prev*dx_prev + dy_prev*dy_prev + dz_prev*dz_prev);
                v_rel = (distance - dist_prev) / time_step;
            else
                v_rel = 0;
            end
            
            % Doppler shift
            doppler(t,u,s) = (v_rel * f_carrier) / c;
            
            % Elevation angle (simplified)
            % ue_zenith vector
            ue_norm = sqrt(ue_pos(u,1)^2 + ue_pos(u,2)^2 + ue_pos(u,3)^2);
            zenith_x = ue_pos(u,1) / ue_norm;
            zenith_y = ue_pos(u,2) / ue_norm;
            zenith_z = ue_pos(u,3) / ue_norm;
            
            % Satellite direction vector
            sat_dir_x = dx / distance;
            sat_dir_y = dy / distance;
            sat_dir_z = dz / distance;
            
            % Dot product (zenith · satellite direction)
            dot_product = zenith_x*sat_dir_x + zenith_y*sat_dir_y + zenith_z*sat_dir_z;
            
            % Elevation = 90° - angle between zenith and sat_dir
            if dot_product > 1, dot_product = 1; end
            if dot_product < -1, dot_product = -1; end
            angle_from_zenith = acos(dot_product) * 180/pi;
            elevation(t,u,s) = 90 - angle_from_zenith;
        end
    end
    
    if mod(t, 500) == 0
        fprintf('  Progress: %.1f%%\n', t/num_steps*100);
    end
end

elapsed = toc;
fprintf('  Progress: 100%% (%.2f seconds)\n', elapsed);

%% Calculate results
fprintf('\n========================================\n');
fprintf('RESULTS\n');
fprintf('========================================\n');

% Doppler
max_doppler_hz = max(abs(doppler(:)));
max_doppler_khz = max_doppler_hz / 1000;
fprintf('\nDOPPLER:\n');
fprintf('  Maximum: %.1f Hz (%.2f kHz)\n', max_doppler_hz, max_doppler_khz);
fprintf('  Theoretical max: %.1f Hz (%.2f kHz)\n', max_doppler_theoretical, max_doppler_theoretical/1000);
fprintf('  Match: %.1f%%\n', max_doppler_hz / max_doppler_theoretical * 100);

% Delay
min_delay_ms = min(delay(:)) * 1000;
max_delay_ms = max(delay(:)) * 1000;
mean_delay_ms = mean(delay(:)) * 1000;
fprintf('\nDELAY:\n');
fprintf('  Minimum: %.2f ms\n', min_delay_ms);
fprintf('  Maximum: %.2f ms\n', max_delay_ms);
fprintf('  Mean: %.2f ms\n', mean_delay_ms);

% Handover
threshold_elev = 10;  % degrees
total_handovers = 0;

for u = 1:num_ues
    current_sat = 1;
    for t = 2:num_steps
        % Find satellite with highest elevation
        elev_s1 = elevation(t,u,1);
        elev_s2 = elevation(t,u,2);
        elev_s3 = elevation(t,u,3);
        
        [max_elev, best_sat] = max([elev_s1, elev_s2, elev_s3]);
        
        if best_sat ~= current_sat && max_elev > threshold_elev
            total_handovers = total_handovers + 1;
            current_sat = best_sat;
        end
    end
end

handovers_per_ue = total_handovers / num_ues;
handover_interval_min = duration_min / handovers_per_ue;

fprintf('\nHANDOVER:\n');
fprintf('  Total handovers: %d\n', total_handovers);
fprintf('  Handovers per UE: %.2f\n', handovers_per_ue);
fprintf('  Average interval: %.1f minutes\n', handover_interval_min);

%% Compare with abstract
fprintf('\n========================================\n');
fprintf('COMPARISON WITH ABSTRACT\n');
fprintf('========================================\n');

fprintf('\n1. Doppler 50.7 kHz: ACTUAL %.2f kHz ', max_doppler_khz);
if abs(max_doppler_khz - 50.7) < 2
    fprintf('✓ MATCH\n');
else
    fprintf('✗ (off by %.1f%%)\n', abs(max_doppler_khz-50.7)/50.7*100);
end

fprintf('2. Delay 1-13 ms: ACTUAL %.1f-%.1f ms ', min_delay_ms, max_delay_ms);
if min_delay_ms <= 2 && max_delay_ms >= 12
    fprintf('✓ MATCH\n');
else
    fprintf('✗\n');
end

fprintf('3. Handover 4-7 min: ACTUAL %.1f min ', handover_interval_min);
if handover_interval_min >= 4 && handover_interval_min <= 7
    fprintf('✓ MATCH\n');
else
    fprintf('✗\n');
end

%% Save
save('leo_dynamics_step1.mat', 'doppler', 'delay', 'elevation', ...
     'max_doppler_khz', 'min_delay_ms', 'max_delay_ms', 'handover_interval_min');

fprintf('\nSaved: leo_dynamics_step1.mat\n');
fprintf('\n=== STEP 1 COMPLETE ===\n');
