%{
Teacher effort model

Purpose: Explore effort choices in a two-teacher tournament, with optional
control-group estimation.

Inputs:
- Parameters defined in this script for the illustration.
- data/derived/teacher_with_incentive.csv from Percentile_calculation.do when
  run_control = true.

Requirements: MATLAB R2021a+ with Optimization Toolbox.

Outputs:
- Effort solutions and winning probabilities: printed table and workspace arrays.
- Teacher response curves: two figures.
- Optional control-group results: regression coefficients, variance estimates,
  a candidate parameter solution, and solver diagnostics.

Saved outputs: CSV solution tables, a MAT results file, and two PDF figures
in output/model/; printed results and diagnostics in output/logs/model.log.

Run this script from top to bottom, or enable run_model in run_all.do.
%}

run_control = false;
script_dir = fileparts(mfilename('fullpath'));
filename = fullfile(script_dir, '..', 'data', 'derived', 'teacher_with_incentive.csv');

project_root = fileparts(script_dir);
model_output_dir = fullfile(project_root, 'output', 'model');
model_log_dir = fullfile(project_root, 'output', 'logs');
if ~isfolder(model_output_dir), mkdir(model_output_dir); end
if ~isfolder(model_log_dir), mkdir(model_log_dir); end

completion_file = fullfile(model_log_dir, 'model_complete.txt');
if isfile(completion_file), delete(completion_file); end
model_log_file = fullfile(model_log_dir, 'model.log');
diary off;
if isfile(model_log_file), delete(model_log_file); end
diary(model_log_file);

try
    %% Control group
    if run_control
        assert(isfile(filename), 'CSV not found: %s', filename);
        dataframe = readtable(filename, 'VariableNamingRule', 'preserve');
        required_vars = {'control', 'z_final_score', 'zmathbase2', ...
            't_taught_any', 'schid'};
        assert(all(ismember(required_vars, dataframe.Properties.VariableNames)), ...
            'The CSV is missing required columns. See required_vars.');

        rows_complete = all(isfinite(dataframe{:, required_vars}), 2);
        dataframe_clean = dataframe(rows_complete, :);
        is_control = dataframe_clean.("control") == 1;
        control_df_clean = dataframe_clean(is_control, :);
        fprintf('Control rows before/after complete-case filter: %d / %d\n', ...
            sum(dataframe.control == 1), height(control_df_clean));
        assert(height(control_df_clean) > 3, 'Too few complete control observations.');

        z_final_score_control_clean = control_df_clean.("z_final_score");
        zmathbase2_control_clean = control_df_clean.("zmathbase2");
        t_taught_any_control_clean = control_df_clean.("t_taught_any");
        schid_control_clean = control_df_clean.("schid");

        % School means use students retained in the estimation sample.
        [school_list, ~, school_idx] = unique(schid_control_clean, 'sorted');
        b_bar_school = accumarray(school_idx, t_taught_any_control_clean, [], @mean);
        A0_bar_school = accumarray(school_idx, zmathbase2_control_clean, [], @mean);
        b_bar_school_individual = b_bar_school(school_idx);
        n_schools = numel(school_list);
        assert(n_schools > 2, 'At least three control schools are required.');
        school_dummies = double(school_idx == (2:n_schools));

        % Production equation: A_ij1 = rho0 + rho1*A_ij0 + rho2*b_j + u_ij.
        % Pooled OLS supplies the first-stage coefficients.
        x = [ones(length(zmathbase2_control_clean), 1), ...
            zmathbase2_control_clean, b_bar_school_individual];
        y = z_final_score_control_clean;
        assert(rank(x) == size(x, 2), 'Control regression is rank deficient.');
        rhos = x \ y;
        rho0_control = rhos(1);
        rho1_control = rhos(2);
        rho2_control = rhos(3);

        fprintf('\n[CONTROL GROUP RESULTS]\n');
        fprintf('rho_0_control (Intercept): %.8f\n', rho0_control);
        fprintf('rho_1_control (Baseline Score): %.8f\n', rho1_control);
        fprintf('rho_2_control (Breadth): %.8f\n', rho2_control);

        % Within-school equation: A_ij1 = a_j + rho1_FE*A_ij0 + epsilon_ij.
        % Under the maintained error model, sigma_epsilon^2 = SSE/(N-K).
        % Breadth is omitted because it is constant within school.
        N = length(y);
        x_fe = [ones(N, 1), zmathbase2_control_clean, school_dummies];
        K = size(x_fe, 2);
        assert(N > K && rank(x_fe) == K, 'School-FE regression is not estimable.');
        beta_hat_control = x_fe \ y;
        y_hat = x_fe * beta_hat_control;
        residuals = y - y_hat;
        sigma2_epsilon_hat = sum(residuals.^2) / (N - K);

        % Var(mean epsilon_j) = sigma_epsilon^2/J_j under independent,
        % homoskedastic student errors. Keep the same school ordering throughout.
        J_per_school = accumarray(school_idx, 1);
        sigma2_epsilon_j_bar = sigma2_epsilon_hat ./ J_per_school;
        fprintf('sigma2_epsilon_hat (within-school residual scale): %.8f\n', ...
            sigma2_epsilon_hat);

        % Between-school equation: estimated a_j = c0 + c1*b_j + residual_j.
        school_intercepts = zeros(n_schools, 1);
        school_intercepts(1) = beta_hat_control(1);
        for j = 2:n_schools
            school_intercepts(j) = beta_hat_control(1) + beta_hat_control(j+1);
        end
        x_breadth = [ones(n_schools, 1), b_bar_school];
        assert(rank(x_breadth) == 2, 'School breadth has no usable variation.');
        beta_stage2 = x_breadth \ school_intercepts;
        school_intercepts_hat = x_breadth * beta_stage2;
        residuals_teacher = school_intercepts - school_intercepts_hat;
        sigma2_eta_raw = sum(residuals_teacher.^2) / (n_schools - 2); % The regression of school intercepts on breadth has two coefficients, hence -2.
        sigma2_eta_hat = max(sigma2_eta_raw - mean(sigma2_epsilon_j_bar), 0); % remove the sampling noise.
        fprintf('sigma2_eta_hat (between-school residual dispersion): %.8f\n', ...
            sigma2_eta_hat);

        %% Control-group moment conditions
        % With gamma=1 and mu_j=rho0+rho1*A0_bar_j+rho2*b_j, invert the FOC:
        % eps_beta_j = delta*rho2*exp(-delta*mu_j + delta^2*v_j/2) - beta0.
        % Moments: E[eps_beta]=0, E[J*eps_beta]=0, E[eps_beta^2]=sigma_beta^2.
        % Class size J is assumed unrelated to beta_j, so it serves as an instrument.
        custom_parameters = [b_bar_school, J_per_school, ...
            sigma2_epsilon_j_bar, A0_bar_school];
        theta = [1; 1; 0.5];  % [beta0, delta, sigma2_beta]
        moment_fun = @(theta) gmm_moments(theta, rho0_control, rho1_control, ...
            rho2_control, sigma2_eta_hat, custom_parameters);
        options = optimoptions('fsolve', 'Display', 'iter', ...
            'FunctionTolerance', 1e-10, 'StepTolerance', 1e-10);
        [theta_hat, m, exitflag, ~, moment_jacobian] = fsolve(moment_fun, theta, options);

        fprintf('\n[CONTROL GROUP MOMENT SOLUTION]\n');
        fprintf('beta0: %.8f; delta: %.8f; sigma2_beta: %.8f\n', theta_hat);
        fprintf('Exit flag: %d; largest absolute moment: %.3g\n', exitflag, max(abs(m)));
        disp('Moment residuals at solution:');
        disp(m);
        % Reject the trivial root delta=beta0=sigma2_beta=0.
        candidate_valid = exitflag > 0 && all(isfinite(theta_hat)) ...
            && all(isfinite(m)) && max(abs(m)) < 1e-6 ...
            && theta_hat(1) > 0 && theta_hat(2) > 1e-6 && theta_hat(3) > 0;
        if ~candidate_valid
            warning('Control moments did not yield an admissible, nondegenerate root.');
        end
        if all(isfinite(moment_jacobian(:)))
            fprintf('Moment Jacobian reciprocal condition number: %.3g\n', ...
                rcond(moment_jacobian));
            if rcond(moment_jacobian) < 1e-10
                warning('Moment Jacobian is nearly singular; inspect identification.');
            end
        end
    else
        fprintf('Control estimation skipped. Set run_control=true to use the CSV.\n');
    end

    %% Two-teacher illustration
    rho_0 = -0.2;
    rho_1 = 0.6136;
    rho_2 = 6;
    gamma = 4;
    delta = 2;
    W1 = 3000;
    W2 = 3000;
    R_high = 7000;
    R_low = 30;
    alpha = 1/600;
    A10 = 0.2;
    A20 = 0.2;
    eta1 = 0.1;
    eta2 = 0.1;
    epsilon = 0.1;
    J = 30;

    sigma2_eta = 0.1;
    sigma2_epsilon = 0.1;
    epsilon_bar = sigma2_epsilon / J;

    % eta_i and epsilon are fixed mean shifts in this illustration; the variances
    % below describe additional centered uncertainty, not these fixed values.
    % The control calculation uses its fitted conditional mean without these shifts.
    % mu_i=rho0+rho1*A_i0+rho2*b_i+eta_i+epsilon; v=sigma2_eta+epsilon_bar.
    % p_i=exp(mu_i)/(exp(mu_i)+exp(mu_j)) is the assumed contest lottery.
    % U_i=-p_i*exp(-alpha*(W_i+R_high))-(1-p_i)*exp(-alpha*(W_i+R_low))
    %     -gamma*exp(-delta*mu_i+delta^2*v/2)-beta_i*b_i.
    % Normal uncertainty is integrated in the achievement payoff; it does not
    % generate the logit contest probability. The FOC is dU_i/db_i=0 below.
    beta0_vals = [0.020, 0.025, 0.027, 0.030, 0.032, 0.042, 0.052, 0.062, 0.003];
    results = NaN(length(beta0_vals), 4);
    options = optimoptions('fsolve', 'Display', 'none', ...
        'FunctionTolerance', 1e-10, 'StepTolerance', 1e-10);

    for i = 1:length(beta0_vals)
        beta0 = beta0_vals(i);
        beta1 = beta0 + 0.1;
        beta2 = beta0 + 0.1;

        % FOC_i = rho2*p_i*(1-p_i)*[exp(-alpha*(W_i+R_low))
        %         -exp(-alpha*(W_i+R_high))]
        %         +gamma*delta*rho2*exp(-delta*mu_i+delta^2*v/2)-beta_i.
        system = @(b) [
            rho_2 * calc_dPi(b(1), b(2), A10, A20, eta1, eta2, rho_0, rho_1, rho_2, epsilon) * ...
            (exp(-alpha*(W1+R_low)) - exp(-alpha*(W1+R_high))) ...
            + gamma*delta*rho_2 * exp(-delta*(rho_0+rho_1*A10+rho_2*b(1)+eta1+epsilon) ...
            + 0.5*delta^2*(epsilon_bar+sigma2_eta)) - beta1;
            rho_2 * calc_dPi(b(2), b(1), A20, A10, eta2, eta1, rho_0, rho_1, rho_2, epsilon) * ...
            (exp(-alpha*(W2+R_low)) - exp(-alpha*(W2+R_high))) ...
            + gamma*delta*rho_2 * exp(-delta*(rho_0+rho_1*A20+rho_2*b(2)+eta2+epsilon) ...
            + 0.5*delta^2*(epsilon_bar+sigma2_eta)) - beta2];

        b0 = [0.6; 0.6];
        [b_star, foc_residual, exitflag] = fsolve(system, b0, options);
        results(i, 1) = beta0;
        if exitflag <= 0 || any(~isfinite(b_star)) || any(~isfinite(foc_residual)) ...
                || max(abs(foc_residual)) > 1e-7 || any(b_star <= 0 | b_star >= 1)
            warning('No verified interior FOC root for beta0=%.4f; row left missing.', beta0);
            continue
        end
        A1 = rho_0 + rho_1*A10 + rho_2*b_star(1) + eta1 + epsilon;
        A2 = rho_0 + rho_1*A20 + rho_2*b_star(2) + eta2 + epsilon;
        pi1 = exp(A1) / (exp(A1) + exp(A2));
        results(i, :) = [beta0, b_star(1), b_star(2), pi1];
    end

    disp('Illustrative interior FOC solutions:');
    disp('Beta_0 | Effort T1 | Effort T2 | Win Prob T1');
    for i = 1:size(results, 1)
        fprintf('%.4f\t%.4f\t%.4f\t%.4f\n', results(i, :));
    end

    %% Response curves
    % For each fixed opponent effort, solve the same own-effort FOC.
    % These are interior stationary responses, not certified global best responses.
    % Separate illustrative cost setting; these curves do not use a table row.
    beta0 = 0.7;
    beta1 = beta0 + 0.1;
    beta2 = beta0 + 0.1;
    b_grid = linspace(0, 1, 101);
    results_sim_1 = [b_grid', NaN(length(b_grid), 1)];
    results_sim_2 = [b_grid', NaN(length(b_grid), 1)];

    for i = 1:length(b_grid)
        b2_fixed = b_grid(i);
        system_1 = @(b1) rho_2 * calc_dPi(b1, b2_fixed, A10, A20, eta1, eta2, ...
            rho_0, rho_1, rho_2, epsilon) * ...
            (exp(-alpha*(W1+R_low)) - exp(-alpha*(W1+R_high))) ...
            + gamma*delta*rho_2 * exp(-delta*(rho_0+rho_1*A10+rho_2*b1+eta1+epsilon) ...
            + 0.5*delta^2*(epsilon_bar+sigma2_eta)) - beta1;
        [b1_single, residual, exitflag] = fsolve(system_1, 0.5, options);
        if exitflag > 0 && isfinite(b1_single) && isfinite(residual) ...
                && abs(residual) < 1e-7 && b1_single > 0 && b1_single < 1
            results_sim_1(i, 2) = b1_single;
        end
    end

    for i = 1:length(b_grid)
        b1_fixed = b_grid(i);
        system_2 = @(b2) rho_2 * calc_dPi(b2, b1_fixed, A20, A10, eta2, eta1, ...
            rho_0, rho_1, rho_2, epsilon) * ...
            (exp(-alpha*(W2+R_low)) - exp(-alpha*(W2+R_high))) ...
            + gamma*delta*rho_2 * exp(-delta*(rho_0+rho_1*A20+rho_2*b2+eta2+epsilon) ...
            + 0.5*delta^2*(epsilon_bar+sigma2_eta)) - beta2;
        [b2_single, residual, exitflag] = fsolve(system_2, 0.5, options);
        if exitflag > 0 && isfinite(b2_single) && isfinite(residual) ...
                && abs(residual) < 1e-7 && b2_single > 0 && b2_single < 1
            results_sim_2(i, 2) = b2_single;
        end
    end
    fprintf('Response-curve roots accepted: teacher 1 %d/101; teacher 2 %d/101.\n', ...
        sum(isfinite(results_sim_1(:, 2))), sum(isfinite(results_sim_2(:, 2))));

    fig_teacher1_response = figure;
    ax_teacher1_response = axes('Parent', fig_teacher1_response);
    plot(results_sim_1(:, 1), results_sim_1(:, 2), 'LineWidth', 2);
    xlabel('Opponent effort (b_2)');
    ylabel('Teacher 1 effort (b_1)');
    title('Teacher 1 interior FOC response');
    xlim([0 1]);
    ylim([0 1]);
    grid on;

    fig_joint_response = figure;
    ax_joint_response = axes('Parent', fig_joint_response);
    plot(results_sim_1(:, 1), results_sim_1(:, 2), 'b-', 'LineWidth', 2); hold on;
    plot(results_sim_2(:, 2), results_sim_2(:, 1), 'r--', 'LineWidth', 2);
    plot(b_grid, b_grid, 'k:');
    xlabel('b_2');
    ylabel('b_1');
    legend('Teacher 1 FOC', 'Teacher 2 FOC', '45-degree line', 'Location', 'best');
    title('Interior response curves of two teachers');
    grid on;

    %% Save results
    writetable(array2table(results, 'VariableNames', ...
        {'beta0', 'effort_teacher1', 'effort_teacher2', 'win_probability_teacher1'}), ...
        fullfile(model_output_dir, 'effort_solutions.csv'));
    writetable(array2table(results_sim_1, 'VariableNames', ...
        {'opponent_effort', 'teacher1_effort'}), ...
        fullfile(model_output_dir, 'teacher1_response.csv'));
    writetable(array2table(results_sim_2, 'VariableNames', ...
        {'opponent_effort', 'teacher2_effort'}), ...
        fullfile(model_output_dir, 'teacher2_response.csv'));
    save(fullfile(model_output_dir, 'model_results.mat'), ...
        'results', 'results_sim_1', 'results_sim_2', 'run_control');
    exportgraphics(ax_teacher1_response, ...
        fullfile(model_output_dir, 'teacher1_response.pdf'), 'ContentType', 'vector');
    exportgraphics(ax_joint_response, ...
        fullfile(model_output_dir, 'joint_response.pdf'), 'ContentType', 'vector');

    fprintf('Model outputs saved in %s\n', model_output_dir);
    diary off;
    marker = fopen(completion_file, 'w');
    assert(marker ~= -1, 'Could not write the model completion marker.');
    fprintf(marker, 'Completed %s\n', datestr(now, 30));
    fclose(marker);
catch model_error
    fprintf(2, '%s\n', getReport(model_error, 'extended', 'hyperlinks', 'off'));
    diary off;
    rethrow(model_error);
end

%% Local functions
function moments = gmm_moments(theta, rho0, rho1, rho2, sigma2_eta_hat, custom_parameters)
    beta = theta(1);
    delta = theta(2);
    sigma2_beta = theta(3);

    b = custom_parameters(:, 1);
    J = custom_parameters(:, 2);
    sigma2_eps_bar = custom_parameters(:, 3);
    A0_bar = custom_parameters(:, 4);
    gamma = 1;

    % Same FOC and moments as the control section, one observation per school.
    mu = rho0 + rho1 .* A0_bar + rho2 .* b;
    eps_beta = gamma*delta*rho2 .* exp(-delta .* mu ...
        + 0.5*delta^2 .* (sigma2_eps_bar + sigma2_eta_hat)) - beta;
    m1 = mean(eps_beta);
    m2 = mean(J .* eps_beta);
    m3 = mean(eps_beta.^2 - sigma2_beta);
    moments = [m1; m2; m3];
end

function dPi = calc_dPi(bi, bj, Ai0, Aj0, etai, etaj, rho_0, rho_1, rho_2, epsilon)
    Ai = rho_0 + rho_1*Ai0 + rho_2*bi + etai + epsilon;
    Aj = rho_0 + rho_1*Aj0 + rho_2*bj + etaj + epsilon;
    pi = exp(Ai) / (exp(Ai) + exp(Aj));
    dPi = pi * (1 - pi);  % The calling FOC multiplies by rho_2.
end

