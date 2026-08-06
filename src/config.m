%% CONFIGURATION FILE - MLight-Handover
function config = get_config()

config = struct();

%% Physical constants
config.R_earth = 6371e3;
config.c = 299792458;
config.G = 6.67430e-11;
config.M_earth = 5.9722e24;
config.GM = config.G * config.M_earth;

%% LEO parameters (3GPP TR 38.821)
config.altitude = 500e3;
config.f_carrier = 2e9;
config.orbit_radius = config.R_earth + config.altitude;
config.orbital_speed = sqrt(config.GM / config.orbit_radius);

%% Simulation parameters
config.num_satellites = 3;
config.num_ues = 50;
config.simulation_duration_sec = 5400;
config.time_step = 1;

%% Coverage area
config.center_lat = 20.5;
config.center_lon = 85.8;
config.coverage_km = 100;

%% 3GPP NB-IoT parameters
config.preamble_length = 839;
config.fs = 1.92e6;
config.cp_length = 128;
config.zc_root_index = 25;

%% DQN Hyperparameters
config.learning_rate = 0.01;
config.discount_factor = 0.95;
config.exploration_rate = 0.30;
config.exploration_decay = 0.995;
config.min_exploration = 0.01;
config.num_episodes = 500;
config.num_states = 8;
config.num_actions = 2;

%% SNR values
config.snr_values = [-5, 0, 5, 10, 15];

%% Random seed
config.random_seed = 42;

end
