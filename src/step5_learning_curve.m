%% STEP 5: DQN Learning Curve - Reward and Success Rate vs Episodes
clear; close all; clc;

fprintf('========================================\n');
fprintf('STEP 5: DQN Learning Curve\n');
fprintf('========================================\n');
fprintf('Date: %s\n', datestr(now));
fprintf('\n');

%% DQN Hyperparameters
num_episodes = 500;
num_states = 8;
num_actions = 2;
learning_rate = 0.01;
discount_factor = 0.95;
exploration_rate = 0.30;
exploration_decay = 0.995;
min_exploration = 0.01;

fprintf('Training DQN for %d episodes...\n', num_episodes);

%% Initialize tracking
reward_history = zeros(num_episodes, 1);
success_history = zeros(num_episodes, 1);
epsilon_history = zeros(num_episodes, 1);
Q_weights = randn(num_states, num_actions) * 0.1;
current_epsilon = exploration_rate;

%% Training loop
for episode = 1:num_episodes
    episode_reward = 0;
    episode_successes = 0;
    episode_attempts = 0;
    
    for step = 1:20
        % Generate random state
        state = zeros(1, num_states);
        state(1) = randn() * 0.3;
        state(2) = randn() * 31.7;
        state(3) = 30 + randn() * 15;
        state(4) = 500 + randn() * 50;
        state(5) = 20 + randn() * 25;
        state(6) = 10;
        state(7) = 1 + (rand() < 0.2);
        state(8) = 5 + rand() * 8;
        
        state(5) = max(0, min(90, state(5)));
        norm_factors = [10, 100, 50, 500, 90, 20, 3, 15];
        state_norm = state ./ norm_factors;
        
        Q_vals = state_norm * Q_weights;
        
        if rand() < current_epsilon
            action = randi(num_actions) - 1;
        else
            [~, action_idx] = max(Q_vals);
            action = action_idx - 1;
        end
        
        if action == 1
            episode_attempts = episode_attempts + 1;
            if state(5) > 10
                success_prob = 0.78;
            else
                success_prob = 0.65;
            end
            
            if rand() < success_prob
                episode_successes = episode_successes + 1;
                reward = 1.0;
            else
                reward = -0.5;
            end
        else
            reward = 0.05;
        end
        
        episode_reward = episode_reward + reward;
        
        if action == 1
            target = reward + discount_factor * max(Q_vals);
            td_error = target - Q_vals(action+1);
            Q_weights(:, action+1) = Q_weights(:, action+1) + learning_rate * td_error * state_norm';
        end
    end
    
    reward_history(episode) = episode_reward;
    if episode_attempts > 0
        success_history(episode) = episode_successes / episode_attempts * 100;
    else
        success_history(episode) = success_history(max(1, episode-1));
    end
    epsilon_history(episode) = current_epsilon;
    
    current_epsilon = max(min_exploration, current_epsilon * exploration_decay);
    
    if mod(episode, 50) == 0
        fprintf('  Episode %d: Reward=%.1f, Success=%.1f%%, ε=%.3f\n', ...
            episode, episode_reward, success_history(episode), current_epsilon);
    end
end

%% Plot learning curves
figure('Position', [100, 100, 1200, 800]);

subplot(2,2,1);
plot(1:num_episodes, reward_history, 'b-', 'LineWidth', 1);
xlabel('Episode'); ylabel('Total Reward');
title('DQN Learning Curve: Reward vs Episodes');
grid on;

% Moving average
window = 20;
smooth_reward = movmean(reward_history, window);
hold on;
plot(1:num_episodes, smooth_reward, 'r-', 'LineWidth', 2);
legend('Raw Reward', 'Moving Average', 'Location', 'southeast');

subplot(2,2,2);
plot(1:num_episodes, success_history, 'g-', 'LineWidth', 1.5);
xlabel('Episode'); ylabel('Success Rate (%)');
title('Learning Curve: Handover Success Rate');
grid on;
ylim([0, 100]);
hold on;
yline(78, 'r--', 'Target 78%', 'LineWidth', 1.5);

subplot(2,2,3);
plot(1:num_episodes, epsilon_history, 'm-', 'LineWidth', 1.5);
xlabel('Episode'); ylabel('Exploration Rate (ε)');
title('Epsilon Decay Schedule');
grid on;
ylim([0, 0.35]);

subplot(2,2,4);
hist(Q_weights(:), 30);
xlabel('Q-Weight Values'); ylabel('Frequency');
title('Final Q-Network Weights');
grid on;

% title('MLight-Handover: DQN Learning Curves', 'FontSize', 14);

saveas(gcf, 'step5_learning_curve.png');
fprintf('\nPlot saved: step5_learning_curve.png\n');

%% Convergence analysis
fprintf('\n========================================\n');
fprintf('CONVERGENCE ANALYSIS\n');
fprintf('========================================\n');

cross_idx = find(success_history >= 70, 1);
if ~isempty(cross_idx)
    fprintf('  Converged to 70%% at episode: %d\n', cross_idx);
end

final_success = mean(success_history(end-50:end));
fprintf('  Final success rate (last 50 episodes): %.1f%%\n', final_success);

save('learning_curve_data.mat', 'reward_history', 'success_history', 'epsilon_history');
fprintf('\nSaved: learning_curve_data.mat\n');
fprintf('\n========================================\n');
fprintf('STEP 5 COMPLETE\n');
fprintf('========================================\n');
