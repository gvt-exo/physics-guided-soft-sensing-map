function lab_dataset = build_lab_aligned_dataset(process, lab, cfg, lag_min, window_min)
%BUILD_LAB_ALIGNED_DATASET Align laboratory points with process history.

    Date_lab = lab.Date(:);
    molarRatioLab = lab.MO_lab(:);
    if isfield(lab, 'Rho_solution_lab')
        rhoSolutionLab_g_cm3 = lab.Rho_solution_lab(:);
    else
        rhoSolutionLab_g_cm3 = lab.Rho_lab(:);
    end

    nLab = numel(Date_lab);
    Date_process_center = NaT(nLab, 1);
    conductivity_mean = nan(nLab, 1);
    conductivity_median = nan(nLab, 1);
    Q_H3PO4_mean = nan(nLab, 1);
    Q_NH3_mean = nan(nLab, 1);
    Q_H2O_mean = nan(nLab, 1);
    valid = false(nLab, 1);
    n_window_points = zeros(nLab, 1);
    n_valid_points = zeros(nLab, 1);

    halfWindow = minutes(window_min / 2);
    minValidPoints = cfg.min_valid_points_window;

    for k = 1:nLab
        if isnat(Date_lab(k))
            continue;
        end

        tProcess = Date_lab(k) - minutes(lag_min);
        Date_process_center(k) = tProcess;

        inWindow = process.Date >= (tProcess - halfWindow) & process.Date <= (tProcess + halfWindow);
        if ~any(inWindow)
            continue;
        end

        validWindow = inWindow & process.is_valid_mode;
        n_window_points(k) = sum(inWindow);
        n_valid_points(k) = sum(validWindow);

        requiredPoints = max(minValidPoints, ceil(cfg.min_valid_fraction_window * n_window_points(k)));
        if n_valid_points(k) < requiredPoints
            continue;
        end

        conductivitySlice = process.conductivity_filtered(validWindow);
        Q_H3PO4_slice = process.Q_H3PO4(validWindow);
        Q_NH3_slice = process.Q_NH3(validWindow);
        Q_H2O_slice = process.Q_H2O(validWindow);

        conductivity_mean(k) = robust_trimmed_mean(conductivitySlice, cfg.flow_window_trim_percent);
        conductivity_median(k) = median(conductivitySlice, 'omitnan');
        Q_H3PO4_mean(k) = robust_trimmed_mean(Q_H3PO4_slice, cfg.flow_window_trim_percent);
        Q_NH3_mean(k) = robust_trimmed_mean(Q_NH3_slice, cfg.flow_window_trim_percent);
        Q_H2O_mean(k) = robust_trimmed_mean(Q_H2O_slice, cfg.flow_window_trim_percent);

        valid(k) = isfinite(conductivity_median(k)) & ...
            isfinite(Q_H3PO4_mean(k)) & isfinite(Q_NH3_mean(k)) & isfinite(Q_H2O_mean(k)) & ...
            isfinite(molarRatioLab(k)) & isfinite(rhoSolutionLab_g_cm3(k)) & ...
            molarRatioLab(k) >= cfg.MO_lab_min & molarRatioLab(k) <= cfg.MO_lab_max & ...
            rhoSolutionLab_g_cm3(k) >= cfg.rho_mix_min & ...
            rhoSolutionLab_g_cm3(k) <= cfg.rho_mix_max;
    end

    totalVolumeFlow_m3_h = Q_H3PO4_mean + Q_NH3_mean ./ cfg.rho_NH3 + Q_H2O_mean;
    rhoPhosphoricAcidDiagnostic_g_cm3 = (rhoSolutionLab_g_cm3 .* 1000 .* totalVolumeFlow_m3_h - ...
        Q_NH3_mean - cfg.rho_H2O .* Q_H2O_mean) ./ (1000 .* Q_H3PO4_mean);
    p2o5MassPctDiagnostic = 100 .* Q_NH3_mean .* cfg.nu_H3PO4 ./ ...
        (molarRatioLab .* cfg.nu_NH3 .* rhoPhosphoricAcidDiagnostic_g_cm3 .* 1000 .* Q_H3PO4_mean .* 1.38);
    p2o5MassPctDiagnostic(~isfinite(p2o5MassPctDiagnostic)) = NaN;

    lab_dataset = table();
    lab_dataset.Date_lab = Date_lab;
    lab_dataset.Date_process_center = Date_process_center;
    lab_dataset.conductivity_mean = conductivity_mean;
    lab_dataset.conductivity_median = conductivity_median;
    lab_dataset.Q_H3PO4_mean = Q_H3PO4_mean;
    lab_dataset.Q_NH3_mean = Q_NH3_mean;
    lab_dataset.Q_H2O_mean = Q_H2O_mean;
    lab_dataset.MO_lab = molarRatioLab;
    lab_dataset.Rho_solution_lab = rhoSolutionLab_g_cm3;
    lab_dataset.Rho_acid_star = rhoPhosphoricAcidDiagnostic_g_cm3;
    lab_dataset.P2O5_star = p2o5MassPctDiagnostic;
    lab_dataset.valid = valid;
    lab_dataset.n_window_points = n_window_points;
    lab_dataset.n_valid_points = n_valid_points;
    lab_dataset.lag_min = repmat(lag_min, nLab, 1);
    lab_dataset.window_min = repmat(window_min, nLab, 1);
end

function y = robust_trimmed_mean(x, trimPercent)
    x = x(isfinite(x));
    if isempty(x)
        y = NaN;
        return;
    end

    x = sort(x);
    n = numel(x);
    trimCount = floor(n * trimPercent / 200);

    if 2 * trimCount >= n
        y = mean(x, 'omitnan');
        return;
    end

    if trimCount > 0
        x = x((trimCount + 1):(n - trimCount));
    end

    y = mean(x, 'omitnan');
end
