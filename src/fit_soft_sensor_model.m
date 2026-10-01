function [model, fit_report] = fit_soft_sensor_model(lab_dataset, cfg, model_type)
%FIT_SOFT_SENSOR_MODEL Jointly fit latent properties and material balance.

    if nargin < 3 || isempty(model_type)
        model_type = 'quadratic';
    end

    ds = lab_dataset(lab_dataset.valid, :);
    if isempty(ds)
        error('fit_soft_sensor_model:NoValidData', 'No valid lab-aligned data for model fitting.');
    end

    conductivityMedian = ds.conductivity_median;
    h3po4FlowMean_m3_h = ds.Q_H3PO4_mean;
    nh3FlowMean_kg_h = ds.Q_NH3_mean;
    h2oFlowMean_m3_h = ds.Q_H2O_mean;
    rhoSolutionLab_g_cm3 = ds.Rho_solution_lab;
    molarRatioLab = ds.MO_lab;
    p2o5MassPctDiagnostic = ds.P2O5_star;
    rhoPhosphoricAcidDiagnostic_g_cm3 = ds.Rho_acid_star;

    [theta0, modelMeta] = build_initial_theta( ...
        conductivityMedian, p2o5MassPctDiagnostic, rhoSolutionLab_g_cm3, ...
        rhoPhosphoricAcidDiagnostic_g_cm3, cfg, model_type);

    scaleRhoSolution = max(std(rhoSolutionLab_g_cm3, 'omitnan'), 1e-3);
    scaleMolarRatio = max(std(molarRatioLab, 'omitnan'), 1e-3);

    objective = @(theta) joint_loss(theta, conductivityMedian, h3po4FlowMean_m3_h, ...
        nh3FlowMean_kg_h, h2oFlowMean_m3_h, rhoSolutionLab_g_cm3, molarRatioLab, ...
        scaleRhoSolution, scaleMolarRatio, cfg, model_type, modelMeta);

    opts = optimset('Display', 'off', ...
        'MaxIter', cfg.optim_max_iter, ...
        'MaxFunEvals', cfg.optim_max_fun_evals);
    [thetaOpt, fval, exitflag, output] = fminsearch(objective, theta0, opts);

    [predTrain, unpacked] = evaluate_model(thetaOpt, conductivityMedian, h3po4FlowMean_m3_h, ...
        nh3FlowMean_kg_h, h2oFlowMean_m3_h, cfg, model_type, modelMeta);
    fitMetrics = compute_basic_metrics(predTrain.Rho_solution_calc, rhoSolutionLab_g_cm3, predTrain.MO_calc, molarRatioLab);

    dRho = unpacked.rhoCoeff(2) + 2 * unpacked.rhoCoeff(1) .* predTrain.P2O5_hat;

    model = struct();
    model.model_type = char(model_type);
    model.feature_name = 'conductivity_median';
    model.theta = thetaOpt(:);
    model.conductivity_train_range = [min(conductivityMedian) max(conductivityMedian)];
    model.p2o5_train_range = [min(predTrain.P2O5_hat) max(predTrain.P2O5_hat)];
    model.rho_acid_train_range = [min(predTrain.Rho_acid_hat) max(predTrain.Rho_acid_hat)];
    model.rho_solution_train_range = [min(predTrain.Rho_solution_calc) max(predTrain.Rho_solution_calc)];
    model.model_meta = modelMeta;
    model.rho_acid_coeff = unpacked.rhoCoeff(:).';
    model.fit_loss = fval;
    model.created_at = datetime('now');
    model.training_n = height(ds);
    model.training_date_range = [min(ds.Date_lab) max(ds.Date_lab)];

    switch lower(model_type)
        case {'linear', 'quadratic'}
            model.p2o5_coeff = unpacked.p2o5Param(:).';
        case 'pchip_spline'
            model.conductivity_knots = modelMeta.spline_knots_x(:).';
            model.P2O5_knots = unpacked.p2o5Param(:).';
    end

    fit_report = struct();
    fit_report.exitflag = exitflag;
    fit_report.output = output;
    fit_report.loss = fval;
    fit_report.scale_rho = scaleRhoSolution;
    fit_report.scale_mo = scaleMolarRatio;
    fit_report.metrics = fitMetrics;
    fit_report.pred_train = predTrain;
    fit_report.nonmonotonic_share = mean(dRho <= 0, 'omitnan');
end

function [theta0, meta] = build_initial_theta(conductivityMedian, p2o5MassPctDiagnostic, rhoSolutionLab_g_cm3, rhoPhosphoricAcidDiagnostic_g_cm3, cfg, model_type)
    meta = struct();
    meta.spline_knots_x = [];

    if any(isfinite(p2o5MassPctDiagnostic))
        pFit = p2o5MassPctDiagnostic;
    else
        pFit = initialize_p2o5_from_conductivity(conductivityMedian, cfg);
    end
    pFit = fillmissing(pFit, 'linear', 'EndValues', 'nearest');

    switch lower(model_type)
        case 'linear'
            if numel(conductivityMedian) >= 2
                p2o5Param = polyfit(conductivityMedian, pFit, 1);
            else
                p2o5Param = [0 mean(pFit)];
            end
            p2o5Param = p2o5Param(:);

        case 'quadratic'
            if numel(conductivityMedian) >= 3
                p2o5Param = polyfit(conductivityMedian, pFit, 2);
            elseif numel(conductivityMedian) >= 2
                tmp = polyfit(conductivityMedian, pFit, 1);
                p2o5Param = [0; tmp(:)];
            else
                p2o5Param = [0; 0; mean(pFit)];
            end
            p2o5Param = p2o5Param(:);

        case 'pchip_spline'
            knotCount = cfg.spline_num_knots;
            [conductivityUnique, ~, uniqueGroup] = unique(conductivityMedian);
            pFitUnique = accumarray(uniqueGroup, pFit, [], @(x) mean(x, 'omitnan'));
            if numel(conductivityUnique) >= knotCount
                knotX = quantile(conductivityUnique, linspace(0, 1, knotCount));
            else
                knotX = linspace(min(conductivityUnique), max(conductivityUnique), knotCount);
            end
            knotX = unique(knotX, 'stable');
            if numel(knotX) < knotCount
                knotX = linspace(min(conductivityUnique), ...
                    max(conductivityUnique) + eps(max(conductivityUnique)), knotCount);
            end
            if numel(conductivityUnique) >= 2
                knotY = interp1(conductivityUnique, pFitUnique, knotX, ...
                    'linear', 'extrap');
            else
                knotY = repmat(pFitUnique(1), size(knotX));
            end
            p2o5Param = knotY(:);
            meta.spline_knots_x = knotX(:);

        otherwise
            error('Unsupported model_type: %s', model_type);
    end

    if any(isfinite(rhoPhosphoricAcidDiagnostic_g_cm3))
        rhoAcid0 = rhoPhosphoricAcidDiagnostic_g_cm3;
    else
        rhoAcid0 = cfg.rho_H3PO4_calc_min + ...
            (rhoSolutionLab_g_cm3 - min(rhoSolutionLab_g_cm3, [], 'omitnan')) ./ ...
            max(range_or_one(rhoSolutionLab_g_cm3), eps) .* ...
            (cfg.rho_H3PO4_calc_max - cfg.rho_H3PO4_calc_min) * 0.25;
    end

    rhoAcid0 = fillmissing(rhoAcid0, 'linear', 'EndValues', 'nearest');
    rhoAcid0(~isfinite(rhoAcid0)) = mean([cfg.rho_H3PO4_calc_min cfg.rho_H3PO4_calc_max]);

    if numel(unique(pFit)) >= 3
        rhoCoeff0 = polyfit(pFit, rhoAcid0, 2);
    else
        rhoCoeff0 = [0 0 mean(rhoAcid0)];
    end

    theta0 = [p2o5Param(:); rhoCoeff0(:)];
end

function loss = joint_loss(theta, conductivityMedian, h3po4FlowMean_m3_h, nh3FlowMean_kg_h, h2oFlowMean_m3_h, rhoSolutionLab_g_cm3, molarRatioLab, ...
    scaleRhoSolution, scaleMolarRatio, cfg, model_type, meta)

    [pred, unpacked] = evaluate_model(theta, conductivityMedian, h3po4FlowMean_m3_h, nh3FlowMean_kg_h, h2oFlowMean_m3_h, cfg, model_type, meta);

    errRho = (pred.Rho_solution_calc - rhoSolutionLab_g_cm3) ./ scaleRhoSolution;
    errMO = (pred.MO_calc - molarRatioLab) ./ scaleMolarRatio;

    if cfg.use_robust_loss
        lossRho = mean(huber_loss(errRho, cfg.huber_delta), 'omitnan');
        lossMO = mean(huber_loss(errMO, cfg.huber_delta), 'omitnan');
    else
        lossRho = mean(errRho .^ 2, 'omitnan');
        lossMO = mean(errMO .^ 2, 'omitnan');
    end

    reg = cfg.regularization_weight * sum(theta .^ 2);
    if strcmpi(model_type, 'pchip_spline')
        reg = reg + cfg.spline_smoothness_weight * sum(diff(theta(1:numel(meta.spline_knots_x)), 2) .^ 2);
    end

    % Soft physical prior for acid density.
    Rho_acid_prior = 0.00008 .* pred.P2O5_hat .^ 2 + ...
                     0.0063 .* pred.P2O5_hat + ...
                     0.9977;

    priorErr = (pred.Rho_acid_hat - Rho_acid_prior) ./ cfg.rho_phosphoric_acid_prior_scale_g_cm3;
    priorPenalty = mean(priorErr .^ 2, 'omitnan');

    % Soft monotonicity penalty for Rho_acid(P2O5).
    rhoCoeff = unpacked.rhoCoeff(:).';  % [c2 c1 c0]
    dRho_dP2O5 = rhoCoeff(2) + 2 .* rhoCoeff(1) .* pred.P2O5_hat;

    monotonicPenalty = mean( ...
        (max(0, -dRho_dP2O5) ./ cfg.rho_phosphoric_acid_derivative_scale) .^ 2, ...
        'omitnan');

    loss = cfg.weight_rho_solution * lossRho + ...
           cfg.weight_molar_ratio * lossMO + ...
           reg + ...
           cfg.rho_phosphoric_acid_prior_weight * priorPenalty + ...
           cfg.rho_phosphoric_acid_monotonic_weight * monotonicPenalty;
end

function [pred, unpacked] = evaluate_model(theta, conductivityMedian, h3po4FlowMean_m3_h, nh3FlowMean_kg_h, h2oFlowMean_m3_h, cfg, model_type, meta)
    [p2o5Param, rhoCoeff] = unpack_theta(theta, model_type, meta);

    switch lower(model_type)
        case {'linear', 'quadratic'}
            P2O5_hat = polyval(p2o5Param(:).', conductivityMedian);
        case 'pchip_spline'
            P2O5_hat = pchip(meta.spline_knots_x, p2o5Param, conductivityMedian);
        otherwise
            error('Unsupported model_type: %s', model_type);
    end

    Rho_acid_hat = polyval(rhoCoeff(:).', P2O5_hat);
    balance = calc_material_balance(P2O5_hat, Rho_acid_hat, h3po4FlowMean_m3_h, nh3FlowMean_kg_h, h2oFlowMean_m3_h, cfg);

    pred = struct();
    pred.P2O5_hat = P2O5_hat(:);
    pred.Rho_acid_hat = Rho_acid_hat(:);
    pred.Rho_solution_calc = balance.Rho_solution_calc(:);
    pred.MO_calc = balance.MO_calc(:);
    pred.balance = balance;

    unpacked = struct();
    unpacked.p2o5Param = p2o5Param(:);
    unpacked.rhoCoeff = rhoCoeff(:);
end

function [p2o5Param, rhoCoeff] = unpack_theta(theta, model_type, meta)
    switch lower(model_type)
        case 'linear'
            nP = 2;
        case 'quadratic'
            nP = 3;
        case 'pchip_spline'
            nP = numel(meta.spline_knots_x);
        otherwise
            error('Unsupported model_type: %s', model_type);
    end

    p2o5Param = theta(1:nP);
    rhoCoeff = theta(nP + 1:nP + 3);
end

function loss = huber_loss(err, delta)
    absErr = abs(err);
    quadratic = absErr <= delta;
    loss = 0.5 .* (err .^ 2) .* quadratic + ...
        (delta .* (absErr - 0.5 .* delta)) .* (~quadratic);
end

function metrics = compute_basic_metrics(Rho_solution_calc, Rho_solution_lab, MO_calc, MO_lab)
    rhoErr = Rho_solution_calc - Rho_solution_lab;
    moErr = MO_calc - MO_lab;

    metrics = struct();
    metrics.MAE_Rho_solution = mean(abs(rhoErr), 'omitnan');
    metrics.RMSE_Rho_solution = sqrt(mean(rhoErr .^ 2, 'omitnan'));
    metrics.Bias_Rho_solution = mean(rhoErr, 'omitnan');
    metrics.MAE_MO = mean(abs(moErr), 'omitnan');
    metrics.RMSE_MO = sqrt(mean(moErr .^ 2, 'omitnan'));
    metrics.Bias_MO = mean(moErr, 'omitnan');
end

function pInit = initialize_p2o5_from_conductivity(conductivityMedian, cfg)
    conductivityMedian = conductivityMedian(:);
    dMin = min(conductivityMedian);
    dMax = max(conductivityMedian);
    if ~(isfinite(dMin) && isfinite(dMax)) || dMax <= dMin
        pInit = repmat(mean([cfg.P2O5_calc__min cfg.P2O5_calc__max]), size(conductivityMedian));
        return;
    end

    dNorm = (conductivityMedian - dMin) ./ (dMax - dMin);
    pInit = cfg.P2O5_calc__max - dNorm .* ...
        (cfg.P2O5_calc__max - cfg.P2O5_calc__min);
end

function r = range_or_one(x)
    r = max(x) - min(x);
    if ~(isfinite(r) && r > 0)
        r = 1;
    end
end
