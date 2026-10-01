function cfg = config_soft_sensor()
%CONFIG_SOFT_SENSOR Configuration for the soft sensor pipeline.

    cfg.nu_NH3 = 17 / 1000;
    cfg.nu_H3PO4 = 98 / 1000;
    cfg.nu_H2SO4 = 98 / 1000;

    cfg.rho_H2O = 998.23;
    cfg.rho_NH3 = 680;

    cfg.P2O5_calc__min = 35;
    cfg.P2O5_calc__max = 80;
    cfg.rho_H3PO4_calc_min = 1.20;
    cfg.rho_H3PO4_calc_max = 1.90;
    cfg.rho_mix_min = 0.90;
    cfg.rho_mix_max = 1.50;
    cfg.MO_lab_min = 0.50;
    cfg.MO_lab_max = 1.80;

    % Process targets.
    cfg.target_molar_ratio = 1.06;
    cfg.target_p2o5_mass_pct = 52;
    cfg.target_rho_solution_g_cm3 = 1.21;

    cfg.lag_grid_min = 0:10:180;
    cfg.window_grid_min = [10 20 30 60];
    cfg.model_candidates = { ...
        'linear'
        'quadratic'
        'pchip_spline'
    };
    cfg.use_robust_loss = true;
    cfg.huber_delta = 1.5;

    cfg.filter.win = 21;
    cfg.filter.thr = 4;
    cfg.filter.expandN = 2;
    cfg.filter.sgolayOrder = 3;
    cfg.filter.sgolayFrame = 5;
    cfg.filter.initHistory = 50;
    cfg.filter.stepSize = 10;
    cfg.filter.lower_clip = -Inf;
    cfg.filter.upper_clip = Inf;
    % Reset every stateful temporal filter when historian continuity is
    % broken. A five-minute threshold is deliberately larger than the
    % nominal one-minute cadence, but far smaller than the repair outage.
    cfg.temporal_gap_reset_minutes = 5;

    cfg.runtime_step_min = 10;

    cfg.nh3_channel_switch_threshold_kg_h = 110;
    cfg.min_nh3_flow_kg_h = 1250;
    cfg.max_h3po4_flow_m3_h = 12;
    cfg.min_h3po4_flow_m3_h = 6;
    cfg.min_h2o_flow_m3_h = 10;
    cfg.max_h2o_flow_m3_h = Inf;
    cfg.conductivity_valid_min = 5;
    cfg.conductivity_valid_max = 30;
    cfg.flow_despike_window = 41;
    cfg.flow_despike_kMad = 5;
    cfg.flow_despike_maxRunLen = 3;
    cfg.flow_despike_expandN = 1;
    cfg.flow_window_trim_percent = 10;

    cfg.min_valid_points_window = 5;
    cfg.min_valid_fraction_window = 0.60;

    cfg.use_so3_correction = false;
    cfg.so3_mass_fraction_in_h3po4 = 1.75 / 100;
    cfg.so3_to_h2so4_mass_factor = 1.225;

    cfg.weight_rho_solution = 1.0;
    cfg.weight_molar_ratio = 1.0;
    cfg.round_molar_ratio_for_reporting = true;
    cfg.molar_ratio_round_digits = 2;
    cfg.regularization_weight = 1e-4;
    cfg.spline_smoothness_weight = 1e-2;
    cfg.rho_phosphoric_acid_prior_weight = 0.01;
    cfg.rho_phosphoric_acid_prior_scale_g_cm3 = 0.10;
    cfg.rho_phosphoric_acid_monotonic_weight = 0.01;
    cfg.rho_phosphoric_acid_derivative_scale = 0.01;

    cfg.spline_num_knots = 5;
    % Prevent latent-property mappings from extrapolating beyond the
    % conductivity support observed in the current training set.
    cfg.clamp_mapping_input_to_training_range = true;
    cfg.optim_max_iter = 3000;
    cfg.optim_max_fun_evals = 12000;

    cfg.initial_train_days = 14; % 14, 10
    cfg.test_window_days = 7; % 7
    cfg.min_train_points = 40;
    cfg.min_test_points = 10; % 10, 6
    cfg.min_fold_count = 2; % 2, 1

    cfg.molar_ratio_tolerance_abs = 0.03;
    cfg.rho_solution_g_cm3_tolerance_abs = 0.01;
    cfg.long_gap_hours = [2 4 8 12];

    cfg.model_selection.tie_rmse_mo = 1e-4;
    cfg.model_selection.tie_rmse_rho = 1e-4;
    cfg.model_selection.prefer_quadratic_tol = 0.01;
end
