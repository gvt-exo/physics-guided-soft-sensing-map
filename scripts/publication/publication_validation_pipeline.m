function outputs = publication_validation_pipeline(repoRoot, mode)
%PUBLICATION_VALIDATION_PIPELINE Reproducible temporal validation and figures.

    arguments
        repoRoot (1, :) char
        mode (1, 1) string = "all"
    end

    rng(20260928, 'twister');
    close all force;

    dataDir = fullfile(repoRoot, 'data', 'publication');
    resultsDir = fullfile(repoRoot, 'results', 'publication');
    % The March--June diagnostic figures are not part of the current
    % manuscript; keep regenerated copies with their numeric results.
    figureDir = fullfile(resultsDir, 'figures');
    ensure_dir(resultsDir);
    ensure_dir(figureDir);

    if mode == "extended"
        outputs = extended_validation_workflow(repoRoot);
        return;
    end

    processFile = fullfile(dataDir, 'process_2026-03-01_2026-06-06.xlsx');
    labFile = fullfile(dataDir, 'laboratory_2026-03-01_2026-06-06.xlsx');
    require_private_input(processFile, 'process', repoRoot);
    require_private_input(labFile, 'laboratory', repoRoot);

    cfg = config_soft_sensor();
    cfg.publication.random_seed = 20260928;
    cfg.publication.regime_boundary = datetime(2026, 5, 21, 0, 0, 0);
    cfg.publication.regime_a_start = datetime(2026, 3, 1, 0, 0, 0);
    cfg.publication.nominal_end = datetime(2026, 6, 7, 0, 0, 0);
    cfg.publication.rolling_step_days = 7;
    cfg.publication.inner_train_days = 9;
    cfg.publication.ridge_lambda_grid = [0 1e-4 1e-3 1e-2 1e-1 1 10 100];
    cfg.publication.ensemble_num_cycles = 100;
    cfg.publication.ensemble_learn_rate = 0.05;
    cfg.publication.ensemble_min_leaf = 10;
    cfg.publication.ensemble_max_splits = 20;
    cfg.publication.use_parallel = true;
    cfg.publication.parallel_workers = 24;

    fprintf('Loading canonical publication data...\n');
    journal = load_journal_data(labFile);
    exportData = load_export_data(processFile);
    lab = struct('Date', journal.Date, 'MO_lab', journal.MO, ...
        'Rho_solution_lab', journal.Rho);

    fprintf('Applying authoritative R&D preprocessing...\n');
    [conductivity, filterReport] = filter_conductivity_stream( ...
        exportData.Conductivity, exportData.Date_1min, cfg);
    process = prepare_process_data(exportData.Date_1min, exportData.AcidFlow, ...
        exportData.AmmoniaFlowFallback, exportData.AmmoniaFlowPrimary, ...
        exportData.WaterFlow, conductivity, cfg);

    if mode == "figures"
        predictions = readtable(fullfile(resultsDir, 'heldout_predictions.csv'), ...
            'TextType', 'string');
        if ~isdatetime(predictions.DateLab)
            predictions.DateLab = datetime(predictions.DateLab);
        end
        metricsSummary = readtable(fullfile(resultsDir, 'metrics_summary.csv'), ...
            'TextType', 'string');
        make_data_regimes_figure(process, exportData.Conductivity, cfg, figureDir);
        make_sparse_sampling_figure(process, lab, cfg, figureDir);
        make_holdout_timeseries_figure(predictions, figureDir);
        make_predicted_measured_figure(predictions, figureDir);
        make_baseline_comparison_figure(metricsSummary, figureDir);
        outputs = struct('results_dir', resultsDir, 'figure_dir', figureDir);
        fprintf('Publication figures regenerated from saved held-out results.\n');
        return;
    end

    datasetCounts = rebuild_dataset_counts(journal, process, lab, cfg);
    writetable(datasetCounts, fullfile(resultsDir, 'dataset_counts.csv'));

    splits = build_publication_splits(journal.Date, cfg);
    writetable(splits, fullfile(resultsDir, 'splits.csv'));

    ensure_parallel_pool(cfg.publication.parallel_workers);
    fprintf('Selecting configuration for regime-A rolling validation...\n');
    firstA = splits(splits.Scenario == "A_within" & splits.Eligible, :);
    firstA = firstA(1, :);
    [configA, tuningA] = select_physics_configuration(process, lab, cfg, ...
        firstA.TrainStart, firstA.TrainEnd, "A_within");

    fprintf('Selecting configuration for A-to-B transfer validation...\n');
    transfer = splits(splits.Scenario == "A_to_B_transfer" & splits.Eligible, :);
    [configTransfer, tuningTransfer] = select_physics_configuration(process, lab, cfg, ...
        transfer.TrainStart, transfer.TrainEnd, "A_to_B_transfer");

    tuning = [tuningA; tuningTransfer];
    writetable(tuning, fullfile(resultsDir, 'configuration_search.csv'));
    selectedConfigurations = selected_config_table(configA, configTransfer, cfg);
    writetable(selectedConfigurations, fullfile(resultsDir, 'selected_configurations.csv'));

    fprintf('Evaluating chronological held-out splits...\n');
    eligibleSplits = splits(splits.Eligible, :);
    metricRows = struct([]);
    predictionParts = cell(0, 1);
    rowIndex = 0;

    for splitIndex = 1:height(eligibleSplits)
        split = eligibleSplits(splitIndex, :);
        if split.Scenario == "A_within"
            selected = configA;
        else
            selected = configTransfer;
        end

        aligned = build_lab_aligned_dataset(process, lab, cfg, ...
            selected.LagMin, selected.WindowMin);
        trainMask = aligned.valid & aligned.Date_lab >= split.TrainStart & ...
            aligned.Date_lab < split.TrainEnd;
        testMask = aligned.valid & aligned.Date_lab >= split.TestStart & ...
            aligned.Date_lab < split.TestEnd;
        trainDs = aligned(trainMask, :);
        testDs = aligned(testMask, :);

        if height(trainDs) < cfg.min_train_points || height(testDs) < cfg.min_test_points
            warning('Skipping %s: only %d train and %d test samples after alignment.', ...
                split.SplitID, height(trainDs), height(testDs));
            continue;
        end

        modelNames = ["physics_guided", "ridge", "physics_only"];
        predictionList = cell(3 + has_ensemble(), 1);

        [physicsModel, ~] = fit_soft_sensor_model(trainDs, cfg, selected.ModelType);
        predictionList{1} = predict_physics_guided(testDs, physicsModel, cfg);

        ridgeModel = fit_ridge_model(trainDs, cfg);
        predictionList{2} = predict_ridge(testDs, ridgeModel, cfg);

        predictionList{3} = predict_physics_only(testDs, cfg);

        if has_ensemble()
            modelNames(end + 1) = "gradient_boosting"; %#ok<AGROW>
            ensembleModel = fit_ensemble_model(trainDs, cfg, split.SplitID);
            predictionList{4} = predict_ensemble(testDs, ensembleModel, cfg);
        end

        for modelIndex = 1:numel(modelNames)
            pred = predictionList{modelIndex};
            metrics = calculate_metrics(pred.MO_pred, pred.MO_lab, ...
                pred.Rho_pred, pred.Rho_lab, cfg);
            rowIndex = rowIndex + 1;
            newMetricRow = make_metric_row(split, modelNames(modelIndex), ...
                selected, height(trainDs), height(testDs), metrics);
            if rowIndex == 1
                metricRows = newMetricRow;
            else
                metricRows(rowIndex) = newMetricRow;
            end
            predictionParts{end + 1, 1} = make_prediction_table(split, ...
                modelNames(modelIndex), pred); %#ok<AGROW>
        end

        fprintf('  %s: %d train, %d test, lag=%d, window=%d, %s\n', ...
            split.SplitID, height(trainDs), height(testDs), selected.LagMin, ...
            selected.WindowMin, selected.ModelType);
    end

    metricsPerSplit = struct2table(metricRows);
    predictions = vertcat(predictionParts{:});
    metricsSummary = aggregate_metrics(predictions, metricsPerSplit, cfg);
    writetable(metricsPerSplit, fullfile(resultsDir, 'metrics_per_split.csv'));
    writetable(metricsSummary, fullfile(resultsDir, 'metrics_summary.csv'));
    writetable(predictions, fullfile(resultsDir, 'heldout_predictions.csv'));

    modelConfigurations = model_configuration_table(cfg, has_ensemble());
    writetable(modelConfigurations, fullfile(resultsDir, 'model_configurations.csv'));

    fprintf('Generating publication figures...\n');
    make_data_regimes_figure(process, exportData.Conductivity, cfg, figureDir);
    make_sparse_sampling_figure(process, lab, cfg, figureDir);
    make_holdout_timeseries_figure(predictions, figureDir);
    make_predicted_measured_figure(predictions, figureDir);
    make_baseline_comparison_figure(metricsSummary, figureDir);

    write_validation_markdown(fullfile(resultsDir, 'VALIDATION.md'), splits, ...
        selectedConfigurations, modelConfigurations, metricsPerSplit, ...
        metricsSummary, datasetCounts, journal, process, filterReport, cfg);

    outputs = struct();
    outputs.results_dir = resultsDir;
    outputs.figure_dir = figureDir;
    outputs.metrics_per_split = metricsPerSplit;
    outputs.metrics_summary = metricsSummary;
    outputs.selected_configurations = selectedConfigurations;
    outputs.dataset_counts = datasetCounts;
    outputs.validation_markdown = fullfile(resultsDir, 'VALIDATION.md');

    fprintf('Publication validation complete.\n');
end

function outputs = extended_validation_workflow(repoRoot)
%EXTENDED_VALIDATION_WORKFLOW External post-repair and rolling validation.

    rng(20261001, 'twister');
    close all force;

    dataDir = fullfile(repoRoot, 'data', 'publication');
    resultsDir = fullfile(repoRoot, 'results', 'publication_extended');
    figureDir = fullfile(repoRoot, 'paper', 'figures');
    ensure_dir(resultsDir);
    ensure_dir(figureDir);

    processFile = fullfile(dataDir, 'process_2026-03-01_2026-09-29.xlsx');
    labFile = fullfile(dataDir, 'laboratory_2026-03-01_2026-10-01.xlsx');
    require_private_input(processFile, 'extended process', repoRoot);
    require_private_input(labFile, 'extended laboratory', repoRoot);

    cfg = config_soft_sensor();
    cfg.publication.random_seed = 20261001;
    cfg.publication.regime_a_start = datetime(2026, 3, 1, 0, 0, 0);
    cfg.publication.rolling_step_days = 7;
    cfg.publication.inner_train_days = 9;
    cfg.publication.ridge_lambda_grid = [0 1e-4 1e-3 1e-2 1e-1 1 10 100];
    cfg.publication.ensemble_num_cycles = 100;
    cfg.publication.ensemble_learn_rate = 0.05;
    cfg.publication.ensemble_min_leaf = 10;
    cfg.publication.ensemble_max_splits = 20;
    cfg.publication.repair_pre_end = datetime(2026, 6, 6, 0, 0, 0);
    cfg.publication.post_start = datetime(2026, 7, 7, 0, 0, 0);
    cfg.publication.use_parallel = true;
    cfg.publication.parallel_workers = 24;

    fprintf('Loading and chronologically ordering the extended dataset...\n');
    journal = load_journal_data(labFile);
    exportData = load_export_data(processFile);
    lab = struct('Date', journal.Date, 'MO_lab', journal.MO, ...
        'Rho_solution_lab', journal.Rho);
    fprintf('Applying gap-aware R&D preprocessing...\n');
    [conductivity, filterReport] = filter_conductivity_stream( ...
        exportData.Conductivity, exportData.Date_1min, cfg);
    process = prepare_process_data(exportData.Date_1min, exportData.AcidFlow, ...
        exportData.AmmoniaFlowFallback, exportData.AmmoniaFlowPrimary, ...
        exportData.WaterFlow, conductivity, cfg);
    postEnd = max(process.Date);
    splits = build_extended_splits(cfg, postEnd);
    splits.NTrainAligned = nan(height(splits), 1);
    splits.NTestAligned = nan(height(splits), 1);
    writetable(splits, fullfile(resultsDir, 'splits.csv'));

    tuningFile = fullfile(resultsDir, 'configuration_search.csv');
    selectedFile = fullfile(resultsDir, 'selected_configurations.csv');
    if isfile(tuningFile) && isfile(selectedFile)
        selectedConfigurations = readtable(selectedFile, 'TextType', 'string');
        if height(selectedConfigurations) == 2 && ...
                all(ismember(["pre_repair_frozen", "post_repair_adapted"], ...
                selectedConfigurations.Scenario))
            tuning = readtable(tuningFile, 'TextType', 'string'); %#ok<NASGU>
            configPre = configuration_from_saved_table(selectedConfigurations, ...
                "pre_repair_frozen");
            configPost = configuration_from_saved_table(selectedConfigurations, ...
                "post_repair_adapted");
            fprintf('Reusing completed configuration search from %s.\n', selectedFile);
        else
            error('Saved configuration checkpoint is incomplete: %s', selectedFile);
        end
    else
        ensure_parallel_pool(cfg.publication.parallel_workers);
        preSelectionStart = cfg.publication.repair_pre_end - days(cfg.initial_train_days);
        fprintf('Selecting the frozen pre-repair configuration from pre-repair data only...\n');
        [configPre, tuningPre] = select_physics_configuration(process, lab, cfg, ...
            preSelectionStart, cfg.publication.repair_pre_end, "pre_repair_frozen");

        firstRolling = splits(splits.Scenario == "post_repair_comparison", :);
        firstRolling = firstRolling(1, :);
        fprintf('Selecting the adapted configuration from the first post-repair training window only...\n');
        [configPost, tuningPost] = select_physics_configuration(process, lab, cfg, ...
            firstRolling.TrainStart, firstRolling.TrainEnd, "post_repair_adapted");
        tuning = [tuningPre; tuningPost];
        writetable(tuning, tuningFile);
        selectedConfigurations = extended_configuration_table(configPre, configPost, cfg);
        writetable(selectedConfigurations, selectedFile);
    end

    alignedPre = build_lab_aligned_dataset(process, lab, cfg, ...
        configPre.LagMin, configPre.WindowMin);
    alignedPost = build_lab_aligned_dataset(process, lab, cfg, ...
        configPost.LagMin, configPost.WindowMin);
    assert(isequal(alignedPre.Date_lab, alignedPost.Date_lab), ...
        'Alignment variants no longer preserve laboratory row identity.');

    preMask = alignedPre.valid & alignedPre.Date_lab >= cfg.publication.regime_a_start & ...
        alignedPre.Date_lab < cfg.publication.repair_pre_end;
    preTrain = alignedPre(preMask, :);
    assert(height(preTrain) >= cfg.min_train_points, ...
        'Insufficient pre-repair training observations: %d.', height(preTrain));

    fprintf('Fitting frozen models on all eligible pre-repair observations...\n');
    [frozenPhysics, ~] = fit_soft_sensor_model(preTrain, cfg, char(configPre.ModelType));
    frozenRidge = fit_ridge_model(preTrain, cfg);
    includeEnsemble = has_ensemble();
    if includeEnsemble
        frozenEnsemble = fit_ensemble_model(preTrain, cfg, "external_frozen");
    else
        frozenEnsemble = [];
    end

    metricRows = struct([]);
    predictionParts = cell(0, 1);
    metricIndex = 0;

    % Full external test: no post-repair observations are used for fitting.
    externalSplit = splits(splits.Scenario == "external_transfer_full", :);
    externalMask = alignedPre.valid & ...
        alignedPre.Date_lab >= externalSplit.TestStart & ...
        alignedPre.Date_lab < externalSplit.TestEnd;
    externalTest = alignedPre(externalMask, :);
    externalRow = splits.Scenario == "external_transfer_full";
    splits.NTrainAligned(externalRow) = height(preTrain);
    splits.NTestAligned(externalRow) = height(externalTest);
    splits.Note(externalRow) = sprintf(['Included: %d eligible pre-repair train and ' ...
        '%d post-repair test laboratory pairs'], height(preTrain), height(externalTest));
    externalNames = ["physics_guided_frozen", "ridge_frozen", "physics_only"];
    externalPredictions = {
        predict_physics_guided(externalTest, frozenPhysics, cfg)
        predict_ridge(externalTest, frozenRidge, cfg)
        predict_physics_only(externalTest, cfg)
    };
    externalTrainN = [height(preTrain), height(preTrain), 0];
    if includeEnsemble
        externalNames(end + 1) = "gradient_boosting_frozen";
        externalPredictions{end + 1} = predict_ensemble( ...
            externalTest, frozenEnsemble, cfg);
        externalTrainN(end + 1) = height(preTrain);
    end
    for modelIndex = 1:numel(externalNames)
        pred = externalPredictions{modelIndex};
        m = calculate_metrics(pred.MO_pred, pred.MO_lab, pred.Rho_pred, ...
            pred.Rho_lab, cfg);
        metricIndex = metricIndex + 1;
        newMetricRow = make_metric_row(externalSplit, ...
            externalNames(modelIndex), configPre, externalTrainN(modelIndex), ...
            height(externalTest), m);
        if metricIndex == 1
            metricRows = newMetricRow;
        else
            metricRows(metricIndex) = newMetricRow;
        end
        predictionParts{end + 1, 1} = make_prediction_table(externalSplit, ...
            externalNames(modelIndex), pred); %#ok<AGROW>
    end
    fprintf('  Full external transfer: %d pre-repair train, %d post-repair test.\n', ...
        height(preTrain), height(externalTest));

    % Paired rolling tests: frozen and adapted models see identical lab rows.
    rollingSplits = splits(splits.Scenario == "post_repair_comparison", :);
    for splitIndex = 1:height(rollingSplits)
        split = rollingSplits(splitIndex, :);
        trainMask = alignedPost.valid & alignedPost.Date_lab >= split.TrainStart & ...
            alignedPost.Date_lab < split.TrainEnd;
        commonTestMask = alignedPre.valid & alignedPost.valid & ...
            alignedPost.Date_lab >= split.TestStart & alignedPost.Date_lab < split.TestEnd;
        adaptedTrain = alignedPost(trainMask, :);
        frozenTest = alignedPre(commonTestMask, :);
        adaptedTest = alignedPost(commonTestMask, :);
        splitRow = splits.SplitID == split.SplitID;
        splits.NTrainAligned(splitRow) = height(adaptedTrain);
        splits.NTestAligned(splitRow) = height(adaptedTest);
        if height(adaptedTrain) < cfg.min_train_points || ...
                height(adaptedTest) < cfg.min_test_points
            splits.Eligible(splitRow) = false;
            splits.Note(splitRow) = sprintf(['Excluded after process-window alignment: ' ...
                '%d train and %d common test pairs; required at least %d/%d'], ...
                height(adaptedTrain), height(adaptedTest), ...
                cfg.min_train_points, cfg.min_test_points);
            warning('Skipping %s: %d train and %d common test samples.', ...
                split.SplitID, height(adaptedTrain), height(adaptedTest));
            continue;
        end
        splits.Eligible(splitRow) = true;
        splits.Note(splitRow) = sprintf(['Included after process-window alignment: ' ...
            '%d train and %d common test pairs'], ...
            height(adaptedTrain), height(adaptedTest));

        [adaptedPhysics, ~] = fit_soft_sensor_model(adaptedTrain, cfg, ...
            char(configPost.ModelType));
        adaptedRidge = fit_ridge_model(adaptedTrain, cfg);
        if includeEnsemble
            adaptedEnsemble = fit_ensemble_model(adaptedTrain, cfg, split.SplitID);
        else
            adaptedEnsemble = [];
        end

        names = ["physics_guided_frozen", "physics_guided_adapted", ...
            "ridge_frozen", "ridge_adapted", "physics_only"];
        preds = {
            predict_physics_guided(frozenTest, frozenPhysics, cfg)
            predict_physics_guided(adaptedTest, adaptedPhysics, cfg)
            predict_ridge(frozenTest, frozenRidge, cfg)
            predict_ridge(adaptedTest, adaptedRidge, cfg)
            predict_physics_only(adaptedTest, cfg)
        };
        trainCounts = [height(preTrain), height(adaptedTrain), ...
            height(preTrain), height(adaptedTrain), 0];
        configs = {configPre, configPost, configPre, configPost, configPost};
        if includeEnsemble
            names(end + 1:end + 2) = ["gradient_boosting_frozen", ...
                "gradient_boosting_adapted"];
            preds{end + 1} = predict_ensemble(frozenTest, frozenEnsemble, cfg);
            preds{end + 1} = predict_ensemble(adaptedTest, adaptedEnsemble, cfg);
            trainCounts(end + 1:end + 2) = [height(preTrain), height(adaptedTrain)];
            configs(end + 1:end + 2) = {configPre, configPost};
        end

        for modelIndex = 1:numel(names)
            pred = preds{modelIndex};
            m = calculate_metrics(pred.MO_pred, pred.MO_lab, pred.Rho_pred, ...
                pred.Rho_lab, cfg);
            metricIndex = metricIndex + 1;
            newMetricRow = make_metric_row(split, names(modelIndex), ...
                configs{modelIndex}, trainCounts(modelIndex), height(adaptedTest), m);
            if metricIndex == 1
                metricRows = newMetricRow;
            else
                metricRows(metricIndex) = newMetricRow;
            end
            predictionParts{end + 1, 1} = make_prediction_table(split, ...
                names(modelIndex), pred); %#ok<AGROW>
        end
        fprintf('[validation %2d/%2d, %3.0f%%] %s: %d adapted train, %d paired test.\n', ...
            splitIndex, height(rollingSplits), 100 * splitIndex / height(rollingSplits), ...
            split.SplitID, height(adaptedTrain), height(adaptedTest));
    end

    metricsPerSplit = struct2table(metricRows);
    predictions = vertcat(predictionParts{:});
    metricsSummary = aggregate_metrics(predictions, metricsPerSplit, cfg);
    modelConfigurations = extended_model_configuration_table(cfg, includeEnsemble);
    datasetCounts = extended_dataset_counts(exportData, journal, process, ...
        alignedPre, alignedPost, filterReport, cfg);

    writetable(splits, fullfile(resultsDir, 'splits.csv'));
    writetable(metricsPerSplit, fullfile(resultsDir, 'metrics_per_split.csv'));
    writetable(metricsSummary, fullfile(resultsDir, 'metrics_summary.csv'));
    writetable(predictions, fullfile(resultsDir, 'heldout_predictions.csv'));
    writetable(modelConfigurations, fullfile(resultsDir, 'model_configurations.csv'));
    writetable(datasetCounts, fullfile(resultsDir, 'dataset_counts.csv'));

    fprintf('Generating extended-period publication figures...\n');
    make_extended_timeline_figure(process, lab, cfg, figureDir);
    make_extended_transfer_figure(predictions, figureDir);
    make_extended_comparison_figure(metricsSummary, figureDir);

    validationFile = fullfile(resultsDir, 'VALIDATION_EXTENDED.md');
    write_extended_validation_markdown(validationFile, splits, ...
        selectedConfigurations, modelConfigurations, metricsPerSplit, ...
        metricsSummary, datasetCounts, exportData, filterReport, cfg);

    outputs = struct();
    outputs.results_dir = resultsDir;
    outputs.figure_dir = figureDir;
    outputs.metrics_per_split = metricsPerSplit;
    outputs.metrics_summary = metricsSummary;
    outputs.selected_configurations = selectedConfigurations;
    outputs.dataset_counts = datasetCounts;
    outputs.validation_markdown = validationFile;
    fprintf('Extended publication validation complete.\n');
end

function splits = build_extended_splits(cfg, postEnd)
    rows = split_row("external_transfer_full", "X01", ...
        cfg.publication.regime_a_start, cfg.publication.repair_pre_end, ...
        cfg.publication.post_start, postEnd, true, ...
        "Fit on all eligible pre-repair observations; test the complete post-repair interval");
    origin = cfg.publication.post_start;
    fold = 1;
    while origin + days(cfg.initial_train_days + cfg.test_window_days) <= postEnd
        rows(end + 1) = split_row("post_repair_comparison", ...
            sprintf('P%02d', fold), origin, ...
            origin + days(cfg.initial_train_days), ...
            origin + days(cfg.initial_train_days), ...
            origin + days(cfg.initial_train_days + cfg.test_window_days), true, ...
            "Identical test rows for frozen pre-repair and rolling-adapted models"); %#ok<AGROW>
        origin = origin + days(cfg.publication.rolling_step_days);
        fold = fold + 1;
    end
    splits = struct2table(rows);
end

function tableOut = extended_configuration_table(configPre, configPost, cfg)
    configs = [configPre; configPost];
    scenario = string({configs.Scenario})';
    lag = [configs.LagMin]';
    window = [configs.WindowMin]';
    model = string({configs.ModelType})';
    innerTrainStart = [configs.InnerTrainStart]';
    innerTrainEnd = [configs.InnerTrainEnd]';
    innerValidationStart = [configs.InnerValidationStart]';
    innerValidationEnd = [configs.InnerValidationEnd]';
    score = [configs.SelectionScore]';
    tableOut = table(scenario, lag, window, model, innerTrainStart, innerTrainEnd, ...
        innerValidationStart, innerValidationEnd, score, ...
        repmat(cfg.publication.inner_train_days, numel(configs), 1), ...
        'VariableNames', {'Scenario', 'LagMin', 'WindowMin', 'ModelType', ...
        'InnerTrainStart', 'InnerTrainEnd', 'InnerValidationStart', ...
        'InnerValidationEnd', 'SelectionScore', 'InnerTrainDays'});
end

function config = configuration_from_saved_table(tableIn, scenarioName)
    row = tableIn(string(tableIn.Scenario) == string(scenarioName), :);
    assert(height(row) == 1, 'Expected one saved row for scenario %s.', scenarioName);
    config = struct();
    config.Scenario = string(row.Scenario(1));
    config.LagMin = double(row.LagMin(1));
    config.WindowMin = double(row.WindowMin(1));
    config.ModelType = string(row.ModelType(1));
    config.InnerTrainStart = saved_datetime(row.InnerTrainStart(1));
    config.InnerTrainEnd = saved_datetime(row.InnerTrainEnd(1));
    config.InnerValidationStart = saved_datetime(row.InnerValidationStart(1));
    config.InnerValidationEnd = saved_datetime(row.InnerValidationEnd(1));
    config.SelectionScore = double(row.SelectionScore(1));
end

function value = saved_datetime(value)
    if isdatetime(value)
        return;
    end
    value = datetime(string(value), 'InputFormat', 'dd-MMM-yyyy', 'Locale', 'en_US');
end

function tableOut = extended_model_configuration_table(cfg, includeEnsemble)
    model = ["physics_guided_frozen"; "physics_guided_adapted"; ...
        "ridge_frozen"; "ridge_adapted"; "physics_only"];
    training = ["All eligible pre-repair observations"; ...
        "Previous 14 post-repair days"; "All eligible pre-repair observations"; ...
        "Previous 14 post-repair days"; "No fitted target mapping"];
    configuration = [
        "Physics-guided mapping selected before repair and then frozen"
        "Physics-guided mapping selected on first post-repair training window; coefficients refit per fold"
        "Ridge lambda selected chronologically within the pre-repair training set"
        "Ridge lambda selected chronologically within each 14-day training set"
        "P2O5 fixed at 52 wt%; unfitted acid-density prior"
    ];
    if includeEnsemble
        model(end + 1:end + 2) = ["gradient_boosting_frozen"; ...
            "gradient_boosting_adapted"];
        training(end + 1:end + 2) = ["All eligible pre-repair observations"; ...
            "Previous 14 post-repair days"];
        configuration(end + 1:end + 2) = [
            sprintf('Fixed LSBoost hyperparameters; %d cycles', cfg.publication.ensemble_num_cycles)
            sprintf('Fixed LSBoost hyperparameters; %d cycles', cfg.publication.ensemble_num_cycles)
        ];
    end
    tableOut = table(model, training, configuration, ...
        'VariableNames', {'Model', 'TrainingStrategy', 'Configuration'});
end

function counts = extended_dataset_counts(exportData, journal, process, ...
        alignedPre, alignedPost, filterReport, cfg)
    post = cfg.publication.post_start;
    preEnd = cfg.publication.repair_pre_end;
    item = [
        "process_rows_total"
        "process_rows_pre_repair"
        "process_rows_post_repair"
        "process_rows_valid_total"
        "temporal_filter_segments"
        "laboratory_rows_imported_including_blank"
        "laboratory_rows_with_timestamp"
        "laboratory_pairs_complete_total"
        "laboratory_pairs_pre_repair"
        "laboratory_pairs_post_repair"
        "aligned_pre_configuration_pre_repair"
        "aligned_pre_configuration_post_repair"
        "aligned_post_configuration_post_repair"
        "source_backward_time_transitions"
        "source_duplicate_timestamps"
    ];
    value = [
        height(process)
        sum(process.Date < preEnd)
        sum(process.Date >= post)
        sum(process.is_valid_mode)
        filterReport.segment_count
        numel(journal.Date_all)
        sum(~isnat(journal.Date_all))
        numel(journal.Date)
        sum(journal.Date < preEnd)
        sum(journal.Date >= post)
        sum(alignedPre.valid & alignedPre.Date_lab < preEnd)
        sum(alignedPre.valid & alignedPre.Date_lab >= post)
        sum(alignedPost.valid & alignedPost.Date_lab >= post)
        exportData.ImportDiagnostics.backward_time_transitions
        exportData.ImportDiagnostics.duplicate_timestamps
    ];
    counts = table(item, value, 'VariableNames', {'Item', 'Count'});
end

function make_extended_timeline_figure(process, lab, cfg, figureDir)
    colors = publication_colors();
    fig = publication_figure([11.5 6.2]);
    tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); hold(ax1, 'on');
    stride = 60;
    idx = (1:stride:height(process))';
    d = process.conductivity_filtered(idx);
    d(~process.is_valid_mode(idx)) = NaN;
    plot(ax1, process.Date(idx), d, 'Color', colors.blue, 'LineWidth', 0.7);
    xline(ax1, cfg.publication.repair_pre_end, '--', 'Maintenance outage begins');
    xline(ax1, cfg.publication.post_start, '--', 'Post-maintenance data begin');
    ylabel(ax1, 'Conductivity signal'); grid(ax1, 'on'); ax1.XTickLabel = [];

    ax2 = nexttile(tl); hold(ax2, 'on');
    yyaxis(ax2, 'left');
    scatter(ax2, lab.Date, lab.MO_lab, 10, colors.blue, 'filled', ...
        'MarkerFaceAlpha', 0.5); ylabel(ax2, 'Molar ratio');
    yyaxis(ax2, 'right');
    plausibleDensity = isfinite(lab.Rho_solution_lab) & ...
        lab.Rho_solution_lab >= 1.15 & lab.Rho_solution_lab <= 1.30;
    scatter(ax2, lab.Date(plausibleDensity), lab.Rho_solution_lab(plausibleDensity), ...
        10, colors.orange, 'filled', 'MarkerFaceAlpha', 0.5);
    ylabel(ax2, 'Density (g cm^{-3})');
    ylim(ax2, [1.15 1.30]);
    xline(ax2, cfg.publication.repair_pre_end, '--');
    xline(ax2, cfg.publication.post_start, '--');
    xlabel(ax2, 'Date in 2026'); grid(ax2, 'on');
    title(tl, 'Extended process and laboratory coverage across the maintenance outage', ...
        'Color', colors.dark, 'FontWeight', 'bold');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_extended_validation_timeline'));
end

function make_extended_transfer_figure(predictions, figureDir)
    colors = publication_colors();
    maskFrozen = predictions.Scenario == "post_repair_comparison" & ...
        predictions.Model == "physics_guided_frozen";
    maskAdapted = predictions.Scenario == "post_repair_comparison" & ...
        predictions.Model == "physics_guided_adapted";
    frozen = sortrows(predictions(maskFrozen, :), 'DateLab');
    adapted = sortrows(predictions(maskAdapted, :), 'DateLab');
    assert(height(frozen) == height(adapted), ...
        'Frozen and adapted prediction rows must be paired.');
    fig = publication_figure([11.5 8.4]);
    tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); hold(ax1, 'on');
    plot(ax1, frozen.DateLab, frozen.MO_Measured, '.', 'Color', colors.dark);
    plot(ax1, frozen.DateLab, frozen.MO_Predicted, '-', 'Color', colors.red);
    plot(ax1, adapted.DateLab, adapted.MO_Predicted, '-', 'Color', colors.blue);
    ylabel(ax1, 'Molar ratio'); grid(ax1, 'on'); ax1.XTickLabel = [];
    legend(ax1, {'Measured', 'Frozen', 'Adapted'}, 'Location', 'best', 'Box', 'off');
    ax2 = nexttile(tl); hold(ax2, 'on');
    plot(ax2, frozen.DateLab, frozen.MO_Residual, '.', 'Color', colors.red);
    plot(ax2, adapted.DateLab, adapted.MO_Residual, '.', 'Color', colors.blue);
    yline(ax2, 0, '-k'); yline(ax2, 0.03, '--k'); yline(ax2, -0.03, '--k');
    ylabel(ax2, 'MO residual'); grid(ax2, 'on'); ax2.XTickLabel = [];
    ax3 = nexttile(tl); hold(ax3, 'on');
    plot(ax3, frozen.DateLab, frozen.Rho_Measured, '.', 'Color', colors.dark);
    plot(ax3, frozen.DateLab, frozen.Rho_Predicted, '-', 'Color', colors.red);
    plot(ax3, adapted.DateLab, adapted.Rho_Predicted, '-', 'Color', colors.orange);
    ylabel(ax3, 'Density'); grid(ax3, 'on'); ax3.XTickLabel = [];
    ax4 = nexttile(tl); hold(ax4, 'on');
    plot(ax4, frozen.DateLab, frozen.Rho_Residual, '.', 'Color', colors.red);
    plot(ax4, adapted.DateLab, adapted.Rho_Residual, '.', 'Color', colors.orange);
    yline(ax4, 0, '-k'); yline(ax4, 0.01, '--k'); yline(ax4, -0.01, '--k');
    ylabel(ax4, 'Density residual'); xlabel(ax4, 'Post-maintenance held-out date'); grid(ax4, 'on');
    title(tl, 'Frozen pre-maintenance model versus 14-day rolling adaptation', ...
        'Color', colors.dark, 'FontWeight', 'bold');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_extended_transfer_timeseries'));
end

function make_extended_comparison_figure(summary, figureDir)
    colors = publication_colors();
    s = summary(summary.Scenario == "post_repair_comparison", :);
    order = ["physics_guided_frozen", "physics_guided_adapted", ...
        "ridge_frozen", "ridge_adapted", "physics_only", ...
        "gradient_boosting_frozen", "gradient_boosting_adapted"];
    order = order(ismember(order, s.Model));
    mo = nan(numel(order), 1); rho = mo;
    for i = 1:numel(order)
        row = s(s.Model == order(i), :);
        mo(i) = row.RMSE_MO / 0.03;
        rho(i) = row.RMSE_Rho / 0.01;
    end
    labels = replace(order, "physics_guided_frozen", "Physics-guided frozen");
    labels = replace(labels, "physics_guided_adapted", "Physics-guided adapted");
    labels = replace(labels, "ridge_frozen", "Ridge frozen");
    labels = replace(labels, "ridge_adapted", "Ridge adapted");
    labels = replace(labels, "physics_only", "Physics-only");
    labels = replace(labels, "gradient_boosting_frozen", "Boosting frozen");
    labels = replace(labels, "gradient_boosting_adapted", "Boosting adapted");
    fig = publication_figure([12.0 5.2]);
    tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); barh(ax1, categorical(labels, labels), mo);
    xline(ax1, 1, '--k', 'Tolerance = 1'); xlabel(ax1, 'Normalized RMSE'); grid(ax1, 'on');
    title(ax1, 'Molar ratio');
    ax2 = nexttile(tl); barh(ax2, categorical(labels, labels), rho);
    xline(ax2, 1, '--k', 'Tolerance = 1'); xlabel(ax2, 'Normalized RMSE'); grid(ax2, 'on');
    title(ax2, 'Density');
    title(tl, 'Post-maintenance held-out performance on identical rolling test samples', ...
        'Color', colors.dark, 'FontWeight', 'bold');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_extended_adaptation_comparison'));
end

function write_extended_validation_markdown(filename, splits, selected, models, ...
        perSplit, summary, counts, exportData, filterReport, cfg)
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    assert(fid >= 0, 'Could not open %s for writing.', filename);
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '# Extended post-repair validation\n\n');
    fprintf(fid, 'Generated by `run_extended_validation.m`. No random shuffling is used. ');
    fprintf(fid, 'The March-June benchmark remains in `results/publication/`; this directory contains the independent extension.\n\n');
    fprintf(fid, '## Data handling\n\n');
    fprintf(fid, '- Process data end at `%s`; complete laboratory pairs end at `%s`.\n', ...
        md_datetime(max(exportData.Date_1min)), md_datetime(max(perSplit.TestEnd)));
    fprintf(fid, '- The repair gap is preserved from `%s` to `%s`; temporal filters reset at gaps over %d minutes.\n', ...
        md_datetime(cfg.publication.repair_pre_end), md_datetime(cfg.publication.post_start), ...
        cfg.temporal_gap_reset_minutes);
    fprintf(fid, '- The source workbook had %d backward timestamp transitions and %d duplicate timestamps. ' + ...
        "All channels were sorted together before filtering; no observation was deleted by sorting.\n", ...
        exportData.ImportDiagnostics.backward_time_transitions, ...
        exportData.ImportDiagnostics.duplicate_timestamps);
    fprintf(fid, '- Conductivity values above %.0f are invalidated before smoothing. The gap-aware filter produced %d independent segments.\n\n', ...
        cfg.conductivity_valid_max, filterReport.segment_count);

    fprintf(fid, '## Exact validation splits\n\n');
    fprintf(fid, ['Intervals are left-closed and right-open. Rolling folds use 14 days for training and the next 7 days for testing. ' ...
        'A calendar window enters the pooled comparison only when process-window alignment leaves at least %d training and %d common test laboratory pairs. ' ...
        'A common test pair must be valid under both the frozen and adapted lag/window configurations so that their comparison uses identical targets.\n\n'], ...
        cfg.min_train_points, cfg.min_test_points);
    fprintf(fid, '| Scenario | Split | Train | Test | N train aligned | N test aligned | Included | Reason |\n');
    fprintf(fid, '|---|---:|---|---|---:|---:|---:|---|\n');
    for i = 1:height(splits)
        fprintf(fid, '| %s | %s | %s to %s | %s to %s | %d | %d | %s | %s |\n', splits.Scenario(i), ...
            splits.SplitID(i), md_date(splits.TrainStart(i)), md_date(splits.TrainEnd(i)), ...
            md_date(splits.TestStart(i)), md_date(splits.TestEnd(i)), ...
            splits.NTrainAligned(i), splits.NTestAligned(i), ...
            string(splits.Eligible(i)), escape_md(splits.Note(i)));
    end
    nPotential = sum(splits.Scenario == "post_repair_comparison");
    nIncluded = sum(splits.Scenario == "post_repair_comparison" & splits.Eligible);
    fprintf(fid, ['\nThus, %d of %d potential post-repair calendar windows enter `post_repair_comparison`. ' ...
        'The other %d are excluded by the pre-specified minimum-sample rule after authoritative process filtering and temporal alignment; ' ...
        'they are not silently omitted and do not contribute to pooled metrics.\n'], ...
        nIncluded, nPotential, nPotential - nIncluded);

    fprintf(fid, '\n## Configuration selection\n\n');
    fprintf(fid, 'The frozen configuration was selected on the last 14 pre-repair days. The adapted configuration was selected once on the first 14 post-repair days and then frozen. Both use a 9-day inner fit and 5-day inner validation. Coefficients are refit for every rolling training window.\n\n');
    fprintf(fid, 'At prediction time, the conductivity input to each fitted latent-property mapping is limited to that model''s training-data range. This prevents unconstrained polynomial or PCHIP extrapolation while leaving the process filters, temporal splits, and test targets unchanged.\n\n');
    fprintf(fid, '| Strategy | Lag min | Window min | Mapping | Inner fit | Inner validation | Score |\n');
    fprintf(fid, '|---|---:|---:|---|---|---|---:|\n');
    for i = 1:height(selected)
        fprintf(fid, '| %s | %d | %d | %s | %s to %s | %s to %s | %.4f |\n', ...
            selected.Scenario(i), selected.LagMin(i), selected.WindowMin(i), ...
            selected.ModelType(i), md_date(selected.InnerTrainStart(i)), ...
            md_date(selected.InnerTrainEnd(i)), md_date(selected.InnerValidationStart(i)), ...
            md_date(selected.InnerValidationEnd(i)), selected.SelectionScore(i));
    end
    fprintf(fid, '\n| Model | Training | Configuration |\n|---|---|---|\n');
    for i = 1:height(models)
        fprintf(fid, '| %s | %s | %s |\n', models.Model(i), ...
            models.TrainingStrategy(i), models.Configuration(i));
    end

    fprintf(fid, '\n## Pooled held-out metrics\n\n');
    fprintf(fid, 'Bias is prediction minus measurement. Fractions are on the 0-1 scale. Per-fold metrics are in `metrics_per_split.csv`.\n\n');
    fprintf(fid, '| Scenario | Model | Splits | N test | RMSE MO | MAE MO | Bias MO | P95 MO | Within 0.03 | RMSE density | MAE density | Bias density | P95 density | Within 0.01 |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary)
        fprintf(fid, '| %s | %s | %d | %d | %.4f | %.4f | %+.4f | %.4f | %.3f | %.4f | %.4f | %+.4f | %.4f | %.3f |\n', ...
            summary.Scenario(i), summary.Model(i), summary.NSplits(i), summary.NTest(i), ...
            summary.RMSE_MO(i), summary.MAE_MO(i), summary.Bias_MO(i), ...
            summary.P95AbsError_MO(i), summary.FractionWithin_MO_0p03(i), ...
            summary.RMSE_Rho(i), summary.MAE_Rho(i), summary.Bias_Rho(i), ...
            summary.P95AbsError_Rho(i), summary.FractionWithin_Rho_0p01(i));
    end

    fprintf(fid, '\n## Dataset counts\n\n| Item | Count |\n|---|---:|\n');
    for i = 1:height(counts)
        fprintf(fid, '| %s | %g |\n', counts.Item(i), counts.Count(i));
    end
    fprintf(fid, '\n## Interpretation and limitations\n\n');
    fprintf(fid, '- `external_transfer_full` is a strict deployment-style test: neither fitting nor hyperparameter selection uses post-repair targets.\n');
    fprintf(fid, '- `post_repair_comparison` compares frozen and adapted models on identical held-out laboratory rows. The adapted configuration is fixed after the first post-repair training window, preventing later-test leakage.\n');
    fprintf(fid, '- Overlapping rolling training windows are intentional; test windows do not overlap. Pooled uncertainty is therefore descriptive and not an independent-sample confidence interval.\n');
    fprintf(fid, '- The supplied historian export ends on 29 September although laboratory records continue into 1 October, so later laboratory values cannot be evaluated.\n');
    fprintf(fid, '- Full per-split results (%d rows) and all predictions are retained in CSV files for audit.\n', height(perSplit));
end

function ensure_dir(pathValue)
    if ~isfolder(pathValue)
        mkdir(pathValue);
    end
end

function ensure_parallel_pool(workerCount)
    if exist('parpool', 'file') ~= 2 || ~license('test', 'Distrib_Computing_Toolbox')
        warning('Parallel Computing Toolbox is unavailable; using serial configuration search.');
        return;
    end
    pool = gcp('nocreate');
    if ~isempty(pool) && pool.NumWorkers ~= workerCount
        fprintf('Replacing the existing %d-worker pool with a %d-worker process pool...\n', ...
            pool.NumWorkers, workerCount);
        delete(pool);
        pool = [];
    end
    if isempty(pool)
        fprintf('Starting a %d-worker process pool...\n', workerCount);
        % The saved local profile is limited to eight workers. Adjusting the
        % transient cluster object avoids changing the user's global MATLAB
        % preferences and permits use of the available physical cores.
        cluster = parcluster("Processes");
        cluster.NumWorkers = workerCount;
        parpool(cluster, workerCount);
    else
        fprintf('Using the existing parallel pool with %d workers.\n', pool.NumWorkers);
    end
end

function tf = has_ensemble()
    tf = exist('fitrensemble', 'file') == 2 && license('test', 'Statistics_Toolbox');
end

function counts = rebuild_dataset_counts(journal, process, lab, cfg)
    boundary = cfg.publication.regime_boundary;
    dsA = build_lab_aligned_dataset(process, lab, cfg, 180, 60);
    dsB = build_lab_aligned_dataset(process, lab, cfg, 20, 20);
    dsAll = build_lab_aligned_dataset(process, lab, cfg, 50, 60);

    item = [
        "process_rows_imported"
        "process_rows_jointly_valid"
        "laboratory_rows_imported"
        "laboratory_pairs_nonmissing"
        "laboratory_pairs_regime_A_raw"
        "laboratory_pairs_regime_B_raw"
        "report_A_valid_lag180_window60"
        "report_B_valid_lag20_window20"
        "combined_valid_lag50_window60"
        "combined_mask_regime_A"
        "combined_mask_regime_B"
    ];
    value = [
        height(process)
        sum(process.is_valid_mode)
        numel(journal.Date_all)
        numel(journal.Date)
        sum(journal.Date < boundary)
        sum(journal.Date >= boundary)
        sum(dsA.valid & dsA.Date_lab < boundary)
        sum(dsB.valid & dsB.Date_lab >= boundary)
        sum(dsAll.valid)
        sum(dsAll.valid & dsAll.Date_lab < boundary)
        sum(dsAll.valid & dsAll.Date_lab >= boundary)
    ];
    notes = [
        "Minute-resolution historian rows"
        "All required channels pass authoritative preprocessing"
        "Rows imported from the laboratory worksheet, including empty targets"
        "Rows with both MO and density present"
        "Nonmissing target pairs before process alignment"
        "Nonmissing target pairs before process alignment"
        "Regime-A report configuration"
        "Regime-B report configuration"
        "Combined-report configuration"
        "Regime-A subset under the combined acceptance mask"
        "Regime-B subset under the combined acceptance mask"
    ];
    counts = table(item, value, notes, 'VariableNames', {'Item', 'Count', 'Definition'});
end

function splits = build_publication_splits(labDates, cfg)
    regimeAStart = cfg.publication.regime_a_start;
    boundary = cfg.publication.regime_boundary;
    trainDays = cfg.initial_train_days;
    testDays = cfg.test_window_days;
    stepDays = cfg.publication.rolling_step_days;
    rows = struct([]);
    k = 0;

    origin = regimeAStart;
    fold = 1;
    while origin + days(trainDays + testDays) <= boundary
        k = k + 1;
        newRow = split_row("A_within", sprintf('A%02d', fold), origin, ...
            origin + days(trainDays), origin + days(trainDays), ...
            origin + days(trainDays + testDays), true, ...
            "Fixed 14-day train and next 7-day test within regime A");
        if k == 1
            rows = newRow;
        else
            rows(k) = newRow;
        end
        origin = origin + days(stepDays);
        fold = fold + 1;
    end

    bStart = boundary;
    bTrainEnd = bStart + days(trainDays);
    bTestEnd = bTrainEnd + days(testDays);
    maxLabDate = max(labDates);
    k = k + 1;
    rows(k) = split_row("B_within", "B00_unavailable", bStart, bTrainEnd, ...
        bTrainEnd, bTestEnd, false, ...
        "No complete 7-day test interval: last laboratory pair is " + string(maxLabDate));

    k = k + 1;
    rows(k) = split_row("A_to_B_transfer", "T01", boundary - days(trainDays), ...
        boundary, boundary, boundary + days(testDays), true, ...
        "Train on the final 14 days of A; test on the first 7 days of B");

    splits = struct2table(rows);
end

function row = split_row(scenario, splitID, trainStart, trainEnd, testStart, testEnd, eligible, note)
    row = struct('Scenario', string(scenario), 'SplitID', string(splitID), ...
        'TrainStart', trainStart, 'TrainEnd', trainEnd, ...
        'TestStart', testStart, 'TestEnd', testEnd, ...
        'Eligible', logical(eligible), 'Note', string(note));
end

function [selected, tuningTable] = select_physics_configuration(process, lab, cfg, trainStart, trainEnd, scenario)
    innerBoundary = trainStart + days(cfg.publication.inner_train_days);
    selected = struct('Scenario', string(scenario), 'LagMin', NaN, ...
        'WindowMin', NaN, 'ModelType', "", 'InnerTrainStart', trainStart, ...
        'InnerTrainEnd', innerBoundary, 'InnerValidationStart', innerBoundary, ...
        'InnerValidationEnd', trainEnd, 'SelectionScore', NaN);

    [lagMatrix, windowMatrix] = ndgrid(cfg.lag_grid_min, cfg.window_grid_min);
    lagValues = lagMatrix(:);
    windowValues = windowMatrix(:);
    nCombinations = numel(lagValues);
    rowCells = cell(nCombinations, 1);
    progressCount = 0;
    progressStart = tic;
    progressStep = max(1, ceil(nCombinations / 20));
    useParallel = isfield(cfg.publication, 'use_parallel') && ...
        cfg.publication.use_parallel && exist('parpool', 'file') == 2 && ...
        license('test', 'Distrib_Computing_Toolbox') && ~isempty(gcp('nocreate'));

    if useParallel
        progressQueue = parallel.pool.DataQueue;
        afterEach(progressQueue, @update_progress);
        fprintf('[config %s] parallel search: %d lag/window combinations, %d mappings each.\n', ...
            string(scenario), nCombinations, numel(cfg.model_candidates));
        parfor combinationIndex = 1:nCombinations
            rowCells{combinationIndex} = evaluate_physics_configuration_combo( ...
                process, lab, cfg, trainStart, innerBoundary, trainEnd, ...
                scenario, lagValues(combinationIndex), windowValues(combinationIndex));
            send(progressQueue, combinationIndex);
        end
    else
        fprintf('[config %s] serial search: %d lag/window combinations, %d mappings each.\n', ...
            string(scenario), nCombinations, numel(cfg.model_candidates));
        for combinationIndex = 1:nCombinations
            rowCells{combinationIndex} = evaluate_physics_configuration_combo( ...
                process, lab, cfg, trainStart, innerBoundary, trainEnd, ...
                scenario, lagValues(combinationIndex), windowValues(combinationIndex));
            update_progress(combinationIndex);
        end
    end

    rows = [rowCells{:}];
    bestScore = Inf;
    bestComplexity = Inf;
    for rowIndex = 1:numel(rows)
        score = rows(rowIndex).SelectionScore;
        complexity = model_complexity(rows(rowIndex).ModelType);
        if isfinite(score) && (score < bestScore - 1e-12 || ...
                (abs(score - bestScore) <= 1e-12 && complexity < bestComplexity))
            bestScore = score;
            bestComplexity = complexity;
            selected.LagMin = rows(rowIndex).LagMin;
            selected.WindowMin = rows(rowIndex).WindowMin;
            selected.ModelType = rows(rowIndex).ModelType;
            selected.SelectionScore = score;
        end
    end

    assert(isfinite(selected.LagMin), ...
        'No configuration could be selected for scenario %s.', scenario);
    tuningTable = struct2table(rows);

    function update_progress(~)
        progressCount = progressCount + 1;
        if progressCount == 1 || mod(progressCount, progressStep) == 0 || ...
                progressCount == nCombinations
            elapsedSeconds = toc(progressStart);
            etaSeconds = elapsedSeconds / progressCount * ...
                (nCombinations - progressCount);
            filled = round(30 * progressCount / nCombinations);
            barText = [repmat('#', 1, filled), repmat('-', 1, 30 - filled)];
            fprintf('[config %s] [%s] %3.0f%% %d/%d | elapsed %s | ETA %s\n', ...
                string(scenario), barText, 100 * progressCount / nCombinations, ...
                progressCount, nCombinations, format_elapsed(elapsedSeconds), ...
                format_elapsed(etaSeconds));
        end
    end
end

function rows = evaluate_physics_configuration_combo(process, lab, cfg, ...
        trainStart, innerBoundary, trainEnd, scenario, lagMin, windowMin)
    aligned = build_lab_aligned_dataset(process, lab, cfg, lagMin, windowMin);
    innerTrain = aligned(aligned.valid & aligned.Date_lab >= trainStart & ...
        aligned.Date_lab < innerBoundary, :);
    innerValidation = aligned(aligned.valid & aligned.Date_lab >= innerBoundary & ...
        aligned.Date_lab < trainEnd, :);
    rows = struct([]);
    for modelIndex = 1:numel(cfg.model_candidates)
        modelType = string(cfg.model_candidates{modelIndex});
        status = "ok";
        score = NaN;
        rmseMO = NaN;
        rmseRho = NaN;
        if height(innerTrain) < cfg.min_train_points || ...
                height(innerValidation) < cfg.min_test_points
            status = "insufficient_samples";
        else
            try
                [model, ~] = fit_soft_sensor_model(innerTrain, cfg, char(modelType));
                pred = predict_physics_guided(innerValidation, model, cfg);
                metrics = calculate_metrics(pred.MO_pred, pred.MO_lab, ...
                    pred.Rho_pred, pred.Rho_lab, cfg);
                rmseMO = metrics.RMSE_MO;
                rmseRho = metrics.RMSE_Rho;
                score = rmseMO / cfg.molar_ratio_tolerance_abs + ...
                    rmseRho / cfg.rho_solution_g_cm3_tolerance_abs;
            catch ME
                status = "failed: " + string(ME.identifier);
            end
        end
        newRow = struct('Scenario', string(scenario), 'LagMin', lagMin, ...
            'WindowMin', windowMin, 'ModelType', modelType, ...
            'InnerTrainN', height(innerTrain), ...
            'InnerValidationN', height(innerValidation), ...
            'RMSE_MO', rmseMO, 'RMSE_Rho', rmseRho, ...
            'SelectionScore', score, 'Status', status);
        if modelIndex == 1
            rows = newRow;
        else
            rows(modelIndex) = newRow;
        end
    end
end

function value = format_elapsed(secondsValue)
    if ~isfinite(secondsValue) || secondsValue < 0
        value = "--:--";
        return;
    end
    totalSeconds = round(secondsValue);
    hoursValue = floor(totalSeconds / 3600);
    minutesValue = floor(mod(totalSeconds, 3600) / 60);
    secondsRemainder = mod(totalSeconds, 60);
    if hoursValue > 0
        value = string(sprintf('%02d:%02d:%02d', hoursValue, minutesValue, secondsRemainder));
    else
        value = string(sprintf('%02d:%02d', minutesValue, secondsRemainder));
    end
end

function value = model_complexity(modelType)
    switch lower(char(modelType))
        case 'linear'
            value = 1;
        case 'quadratic'
            value = 2;
        case 'pchip_spline'
            value = 3;
        otherwise
            value = 99;
    end
end

function tableOut = selected_config_table(configA, configTransfer, cfg)
    configs = [configA; configTransfer];
    scenario = strings(numel(configs), 1);
    lag = nan(numel(configs), 1);
    window = nan(numel(configs), 1);
    model = strings(numel(configs), 1);
    innerTrainStart = NaT(numel(configs), 1);
    innerTrainEnd = NaT(numel(configs), 1);
    innerValidationStart = NaT(numel(configs), 1);
    innerValidationEnd = NaT(numel(configs), 1);
    score = nan(numel(configs), 1);
    for i = 1:numel(configs)
        scenario(i) = configs(i).Scenario;
        lag(i) = configs(i).LagMin;
        window(i) = configs(i).WindowMin;
        model(i) = configs(i).ModelType;
        innerTrainStart(i) = configs(i).InnerTrainStart;
        innerTrainEnd(i) = configs(i).InnerTrainEnd;
        innerValidationStart(i) = configs(i).InnerValidationStart;
        innerValidationEnd(i) = configs(i).InnerValidationEnd;
        score(i) = configs(i).SelectionScore;
    end
    tableOut = table(scenario, lag, window, model, innerTrainStart, innerTrainEnd, ...
        innerValidationStart, innerValidationEnd, score, ...
        repmat(cfg.publication.inner_train_days, numel(configs), 1), ...
        'VariableNames', {'Scenario', 'LagMin', 'WindowMin', 'ModelType', ...
        'InnerTrainStart', 'InnerTrainEnd', 'InnerValidationStart', ...
        'InnerValidationEnd', 'SelectionScore', 'InnerTrainDays'});
end

function pred = predict_physics_guided(ds, model, cfg)
    conductivity = ds.conductivity_median;
    if isfield(cfg, 'clamp_mapping_input_to_training_range') && ...
            cfg.clamp_mapping_input_to_training_range
        trainRange = model.conductivity_train_range;
        conductivity = min(max(conductivity, trainRange(1)), trainRange(2));
    end
    switch lower(model.model_type)
        case {'linear', 'quadratic'}
            p2o5 = polyval(model.p2o5_coeff, conductivity);
        case 'pchip_spline'
            p2o5 = pchip(model.conductivity_knots, model.P2O5_knots, conductivity);
        otherwise
            error('Unsupported physics-guided model type: %s', model.model_type);
    end
    rhoAcid = polyval(model.rho_acid_coeff, p2o5);
    balance = calc_material_balance(p2o5, rhoAcid, ds.Q_H3PO4_mean, ...
        ds.Q_NH3_mean, ds.Q_H2O_mean, cfg);
    pred = base_prediction_table(ds, round_mo(balance.MO_calc, cfg), ...
        balance.Rho_solution_calc);
end

function model = fit_ridge_model(trainDs, cfg)
    X = baseline_features(trainDs);
    yMO = trainDs.MO_lab;
    yRho = trainDs.Rho_solution_lab;
    dates = trainDs.Date_lab;
    splitTime = min(dates) + (max(dates) - min(dates)) * 2 / 3;
    innerTrain = dates < splitTime;
    innerValidation = dates >= splitTime;
    lambdas = cfg.publication.ridge_lambda_grid;
    bestLambda = 1;
    bestScore = Inf;

    if sum(innerTrain) >= 10 && sum(innerValidation) >= 5
        for lambda = lambdas
            candidate = solve_ridge(X(innerTrain, :), yMO(innerTrain), ...
                yRho(innerTrain), lambda);
            [mo, rho] = apply_ridge(X(innerValidation, :), candidate);
            m = calculate_metrics(round_mo(mo, cfg), yMO(innerValidation), ...
                rho, yRho(innerValidation), cfg);
            score = m.RMSE_MO / cfg.molar_ratio_tolerance_abs + ...
                m.RMSE_Rho / cfg.rho_solution_g_cm3_tolerance_abs;
            if score < bestScore
                bestScore = score;
                bestLambda = lambda;
            end
        end
    end
    model = solve_ridge(X, yMO, yRho, bestLambda);
    model.lambda = bestLambda;
end

function model = solve_ridge(X, yMO, yRho, lambda)
    mu = mean(X, 1, 'omitnan');
    sigma = std(X, 0, 1, 'omitnan');
    sigma(~isfinite(sigma) | sigma < eps) = 1;
    Xs = (X - mu) ./ sigma;
    Z = [ones(size(Xs, 1), 1), Xs];
    penalty = diag([0, ones(1, size(Xs, 2))]);
    model.mu = mu;
    model.sigma = sigma;
    model.beta_mo = (Z' * Z + lambda * penalty) \ (Z' * yMO);
    model.beta_rho = (Z' * Z + lambda * penalty) \ (Z' * yRho);
end

function [mo, rho] = apply_ridge(X, model)
    Xs = (X - model.mu) ./ model.sigma;
    Z = [ones(size(Xs, 1), 1), Xs];
    mo = Z * model.beta_mo;
    rho = Z * model.beta_rho;
end

function pred = predict_ridge(ds, model, cfg)
    [mo, rho] = apply_ridge(baseline_features(ds), model);
    pred = base_prediction_table(ds, round_mo(mo, cfg), rho);
end

function X = baseline_features(ds)
    X = [ds.conductivity_median, ds.Q_H3PO4_mean, ds.Q_NH3_mean, ds.Q_H2O_mean];
end

function pred = predict_physics_only(ds, cfg)
    p2o5 = repmat(cfg.target_p2o5_mass_pct, height(ds), 1);
    rhoAcid = 0.00008 .* p2o5 .^ 2 + 0.0063 .* p2o5 + 0.9977;
    balance = calc_material_balance(p2o5, rhoAcid, ds.Q_H3PO4_mean, ...
        ds.Q_NH3_mean, ds.Q_H2O_mean, cfg);
    pred = base_prediction_table(ds, round_mo(balance.MO_calc, cfg), ...
        balance.Rho_solution_calc);
end

function model = fit_ensemble_model(trainDs, cfg, splitID)
    X = baseline_features(trainDs);
    seedOffset = sum(double(char(splitID)));
    rng(cfg.publication.random_seed + seedOffset, 'twister');
    learner = templateTree('MinLeafSize', cfg.publication.ensemble_min_leaf, ...
        'MaxNumSplits', cfg.publication.ensemble_max_splits);
    args = {'Method', 'LSBoost', ...
        'NumLearningCycles', cfg.publication.ensemble_num_cycles, ...
        'LearnRate', cfg.publication.ensemble_learn_rate, ...
        'Learners', learner};
    model.mo = fitrensemble(X, trainDs.MO_lab, args{:});
    model.rho = fitrensemble(X, trainDs.Rho_solution_lab, args{:});
end

function pred = predict_ensemble(ds, model, cfg)
    X = baseline_features(ds);
    mo = predict(model.mo, X);
    rho = predict(model.rho, X);
    pred = base_prediction_table(ds, round_mo(mo, cfg), rho);
end

function pred = base_prediction_table(ds, mo, rho)
    pred = table(ds.Date_lab, ds.MO_lab, ds.Rho_solution_lab, mo(:), rho(:), ...
        'VariableNames', {'Date_lab', 'MO_lab', 'Rho_lab', 'MO_pred', 'Rho_pred'});
end

function value = round_mo(value, cfg)
    if cfg.round_molar_ratio_for_reporting
        value = round(value, cfg.molar_ratio_round_digits);
    end
end

function metrics = calculate_metrics(moPred, moLab, rhoPred, rhoLab, cfg)
    valid = isfinite(moPred) & isfinite(moLab) & isfinite(rhoPred) & isfinite(rhoLab);
    moError = moPred(valid) - moLab(valid);
    rhoError = rhoPred(valid) - rhoLab(valid);
    metrics = struct();
    metrics.N = sum(valid);
    metrics.RMSE_MO = sqrt(mean(moError .^ 2, 'omitnan'));
    metrics.MAE_MO = mean(abs(moError), 'omitnan');
    metrics.Bias_MO = mean(moError, 'omitnan');
    metrics.P95AbsError_MO = safe_percentile(abs(moError), 95);
    metrics.FractionWithin_MO_0p03 = mean(abs(moError) <= cfg.molar_ratio_tolerance_abs);
    metrics.RMSE_Rho = sqrt(mean(rhoError .^ 2, 'omitnan'));
    metrics.MAE_Rho = mean(abs(rhoError), 'omitnan');
    metrics.Bias_Rho = mean(rhoError, 'omitnan');
    metrics.P95AbsError_Rho = safe_percentile(abs(rhoError), 95);
    metrics.FractionWithin_Rho_0p01 = mean(abs(rhoError) <= cfg.rho_solution_g_cm3_tolerance_abs);
end

function value = safe_percentile(x, percentile)
    x = x(isfinite(x));
    if isempty(x)
        value = NaN;
    else
        value = prctile(x, percentile);
    end
end

function row = make_metric_row(split, modelName, selected, trainN, testN, m)
    row = struct('Scenario', split.Scenario, 'SplitID', split.SplitID, ...
        'Model', string(modelName), 'TrainStart', split.TrainStart, ...
        'TrainEnd', split.TrainEnd, 'TestStart', split.TestStart, ...
        'TestEnd', split.TestEnd, 'LagMin', selected.LagMin, ...
        'WindowMin', selected.WindowMin, 'PhysicsMapping', selected.ModelType, ...
        'NTrain', trainN, 'NTest', testN, ...
        'RMSE_MO', m.RMSE_MO, 'MAE_MO', m.MAE_MO, ...
        'Bias_MO', m.Bias_MO, 'P95AbsError_MO', m.P95AbsError_MO, ...
        'FractionWithin_MO_0p03', m.FractionWithin_MO_0p03, ...
        'RMSE_Rho', m.RMSE_Rho, 'MAE_Rho', m.MAE_Rho, ...
        'Bias_Rho', m.Bias_Rho, 'P95AbsError_Rho', m.P95AbsError_Rho, ...
        'FractionWithin_Rho_0p01', m.FractionWithin_Rho_0p01);
end

function output = make_prediction_table(split, modelName, pred)
    n = height(pred);
    output = table(repmat(split.Scenario, n, 1), repmat(split.SplitID, n, 1), ...
        repmat(string(modelName), n, 1), pred.Date_lab, pred.MO_lab, pred.MO_pred, ...
        pred.MO_pred - pred.MO_lab, pred.Rho_lab, pred.Rho_pred, ...
        pred.Rho_pred - pred.Rho_lab, ...
        'VariableNames', {'Scenario', 'SplitID', 'Model', 'DateLab', ...
        'MO_Measured', 'MO_Predicted', 'MO_Residual', ...
        'Rho_Measured', 'Rho_Predicted', 'Rho_Residual'});
end

function summary = aggregate_metrics(predictions, metricsPerSplit, cfg)
    scenarios = unique(predictions.Scenario, 'stable');
    models = unique(predictions.Model, 'stable');
    rows = struct([]);
    idx = 0;
    for s = 1:numel(scenarios)
        for m = 1:numel(models)
            mask = predictions.Scenario == scenarios(s) & predictions.Model == models(m);
            if ~any(mask)
                continue;
            end
            subset = predictions(mask, :);
            metrics = calculate_metrics(subset.MO_Predicted, subset.MO_Measured, ...
                subset.Rho_Predicted, subset.Rho_Measured, cfg);
            splitMask = metricsPerSplit.Scenario == scenarios(s) & ...
                metricsPerSplit.Model == models(m);
            idx = idx + 1;
            newRow = struct('Scenario', scenarios(s), 'Model', models(m), ...
                'NSplits', sum(splitMask), ...
                'NTrainMin', min(metricsPerSplit.NTrain(splitMask)), ...
                'NTrainMax', max(metricsPerSplit.NTrain(splitMask)), ...
                'NTest', metrics.N, 'RMSE_MO', metrics.RMSE_MO, ...
                'MAE_MO', metrics.MAE_MO, 'Bias_MO', metrics.Bias_MO, ...
                'P95AbsError_MO', metrics.P95AbsError_MO, ...
                'FractionWithin_MO_0p03', metrics.FractionWithin_MO_0p03, ...
                'RMSE_Rho', metrics.RMSE_Rho, 'MAE_Rho', metrics.MAE_Rho, ...
                'Bias_Rho', metrics.Bias_Rho, ...
                'P95AbsError_Rho', metrics.P95AbsError_Rho, ...
                'FractionWithin_Rho_0p01', metrics.FractionWithin_Rho_0p01);
            if idx == 1
                rows = newRow;
            else
                rows(idx) = newRow;
            end
        end
    end
    summary = struct2table(rows);
end

function tableOut = model_configuration_table(cfg, includeEnsemble)
    model = ["physics_guided"; "ridge"; "physics_only"];
    inputs = [
        "conductivity, acid flow, ammonia flow, water flow"
        "conductivity, acid flow, ammonia flow, water flow"
        "acid flow, ammonia flow, water flow"
    ];
    configuration = [
        "Joint latent-property fit; linear/quadratic/PCHIP selected chronologically"
        "Standardized multivariate ridge; lambda selected by chronological inner holdout"
        "P2O5 fixed at 52 wt%; acid density from the unfitted physical prior"
    ];
    if includeEnsemble
        model(end + 1) = "gradient_boosting";
        inputs(end + 1) = "conductivity, acid flow, ammonia flow, water flow";
        configuration(end + 1) = sprintf('LSBoost, %d cycles, learn rate %.3g, min leaf %d, max splits %d', ...
            cfg.publication.ensemble_num_cycles, cfg.publication.ensemble_learn_rate, ...
            cfg.publication.ensemble_min_leaf, cfg.publication.ensemble_max_splits);
    end
    tableOut = table(model, inputs, configuration, ...
        'VariableNames', {'Model', 'Inputs', 'Configuration'});
end

function make_data_regimes_figure(process, rawConductivity, cfg, figureDir)
    [date10, rawD, validD, acid, ammonia, water, invalidShare] = ...
        aggregate_process_for_figure(process, rawConductivity, 10);
    colors = publication_colors();
    fig = publication_figure([11.5 8.5]);
    tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    yRaw = {rawD, [], [], []};
    yValid = {validD, acid, ammonia, water};
    labels = {'Conductivity signal', 'Acid flow (m^3 h^{-1})', ...
        'Ammonia flow (kg h^{-1})', 'Water flow (m^3 h^{-1})'};
    for k = 1:4
        ax = nexttile(tl);
        hold(ax, 'on');
        if k == 1
            plot(ax, date10, yRaw{k}, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.6);
        end
        plot(ax, date10, yValid{k}, 'Color', colors.blue, 'LineWidth', 0.9);
        bad = invalidShare > 0;
        scatter(ax, date10(bad), yValid{k}(bad), 5, colors.red, 'filled', ...
            'MarkerFaceAlpha', 0.45, 'MarkerEdgeAlpha', 0.45);
        xline(ax, cfg.publication.regime_boundary, '--', '21 May', ...
            'Color', colors.dark, 'LabelOrientation', 'horizontal', ...
            'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
        ylabel(ax, labels{k});
        grid(ax, 'on');
        if k < 4
            ax.XTickLabel = [];
        else
            xlabel(ax, 'Date in 2026');
        end
    end
    title(tl, 'Process signals, invalid intervals, and the operating-regime boundary', ...
        'Color', 'black');
    subtitle(tl, 'Red markers denote 10-minute bins containing at least one invalid minute', ...
        'Color', 'black');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_data_regimes'));
end

function make_sparse_sampling_figure(process, lab, cfg, figureDir)
    [date10, ~, validD] = aggregate_process_for_figure(process, ...
        process.conductivity_filtered_raw, 10);
    colors = publication_colors();
    fig = publication_figure([11.5 7.5]);
    tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl);
    plot(ax1, date10, validD, 'Color', [0.65 0.65 0.65], 'LineWidth', 0.7);
    ylabel(ax1, 'Conductivity signal'); grid(ax1, 'on'); ax1.XTickLabel = [];
    ax2 = nexttile(tl);
    scatter(ax2, lab.Date, lab.MO_lab, 13, colors.blue, 'filled');
    ylabel(ax2, 'Molar ratio'); grid(ax2, 'on'); ax2.XTickLabel = [];
    ax3 = nexttile(tl);
    validRho = isfinite(lab.Rho_solution_lab) & ...
        lab.Rho_solution_lab >= cfg.rho_mix_min & lab.Rho_solution_lab <= cfg.rho_mix_max;
    scatter(ax3, lab.Date(validRho), lab.Rho_solution_lab(validRho), 13, ...
        colors.orange, 'filled');
    hold(ax3, 'on');
    invalidRho = ~validRho;
    if any(invalidRho)
        markerLevel = min(1.34, max(lab.Rho_solution_lab(validRho)) + 0.02);
        scatter(ax3, lab.Date(invalidRho), repmat(markerLevel, sum(invalidRho), 1), ...
            28, colors.red, '^', 'filled');
        legend(ax3, {'Plausible references', 'Out-of-range source value'}, ...
            'Location', 'best', 'Box', 'off');
        ylim(ax3, [min(lab.Rho_solution_lab(validRho)) - 0.01, markerLevel + 0.01]);
    end
    ylabel(ax3, 'Density (g cm^{-3})'); xlabel(ax3, 'Date in 2026'); grid(ax3, 'on');
    axesList = [ax1 ax2 ax3];
    for ax = axesList
        xline(ax, cfg.publication.regime_boundary, '--', '21 May', ...
            'Color', colors.dark, 'LabelOrientation', 'horizontal', ...
            'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
    end
    title(tl, 'Sparse laboratory references on the process timeline', 'Color', 'black');
    subtitle(tl, sprintf('%d paired laboratory observations over %d minute records', ...
        numel(lab.Date), height(process)), 'Color', 'black');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_sparse_sampling'));
end

function make_holdout_timeseries_figure(predictions, figureDir)
    colors = publication_colors();
    mask = predictions.Scenario == "A_to_B_transfer" & predictions.Model == "physics_guided";
    p = sortrows(predictions(mask, :), 'DateLab');
    assert(~isempty(p), 'Transfer predictions are required for the holdout figure.');
    fig = publication_figure([11.5 8.5]);
    tl = tiledlayout(fig, 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    ax1 = nexttile(tl); hold(ax1, 'on');
    plot(ax1, p.DateLab, p.MO_Measured, 'o-', 'Color', colors.dark, ...
        'MarkerFaceColor', 'white', 'MarkerSize', 3.5, 'LineWidth', 0.9);
    plot(ax1, p.DateLab, p.MO_Predicted, '.-', 'Color', colors.blue, ...
        'MarkerSize', 10, 'LineWidth', 1.0);
    ylabel(ax1, 'Molar ratio'); grid(ax1, 'on'); legend(ax1, {'Measured', 'Predicted'}, ...
        'Location', 'best', 'Box', 'off'); ax1.XTickLabel = [];

    ax2 = nexttile(tl); hold(ax2, 'on');
    plot(ax2, p.DateLab, p.MO_Residual, '.-', 'Color', colors.blue, ...
        'MarkerSize', 8, 'LineWidth', 0.8);
    yline(ax2, 0, '-', 'Color', [0.6 0.6 0.6]);
    yline(ax2, 0.03, '--', 'Color', colors.red); yline(ax2, -0.03, '--', 'Color', colors.red);
    ylabel(ax2, 'MO residual'); grid(ax2, 'on'); ax2.XTickLabel = [];

    ax3 = nexttile(tl); hold(ax3, 'on');
    plot(ax3, p.DateLab, p.Rho_Measured, 'o-', 'Color', colors.dark, ...
        'MarkerFaceColor', 'white', 'MarkerSize', 3.5, 'LineWidth', 0.9);
    plot(ax3, p.DateLab, p.Rho_Predicted, '.-', 'Color', colors.orange, ...
        'MarkerSize', 10, 'LineWidth', 1.0);
    ylabel(ax3, 'Density (g cm^{-3})'); grid(ax3, 'on'); ax3.XTickLabel = [];

    ax4 = nexttile(tl); hold(ax4, 'on');
    plot(ax4, p.DateLab, p.Rho_Residual, '.-', 'Color', colors.orange, ...
        'MarkerSize', 8, 'LineWidth', 0.8);
    yline(ax4, 0, '-', 'Color', [0.6 0.6 0.6]);
    yline(ax4, 0.01, '--', 'Color', colors.red); yline(ax4, -0.01, '--', 'Color', colors.red);
    ylabel(ax4, 'Density residual'); xlabel(ax4, 'Held-out date in regime B'); grid(ax4, 'on');

    title(tl, 'A-to-B transfer holdout: physics-guided prediction and residuals', ...
        'Color', 'black');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_holdout_timeseries'));
end

function make_predicted_measured_figure(predictions, figureDir)
    colors = publication_colors();
    p = predictions(predictions.Model == "physics_guided", :);
    fig = publication_figure([10.5 8.5]);
    tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    scenarioNames = ["A_within", "A_to_B_transfer"];
    scenarioLabels = {'Regime A rolling tests', 'Regime B transfer test'};
    scenarioColors = [colors.blue; colors.orange];
    for s = 1:numel(scenarioNames)
        mask = p.Scenario == scenarioNames(s);
        axMO = nexttile(tl, s); hold(axMO, 'on');
        scatter(axMO, p.MO_Measured(mask), p.MO_Predicted(mask), 18, ...
            scenarioColors(s, :), 'filled', 'MarkerFaceAlpha', 0.55);
        add_identity_line(axMO);
        xlabel(axMO, 'Measured molar ratio'); ylabel(axMO, 'Predicted molar ratio');
        title(axMO, scenarioLabels{s}); grid(axMO, 'on'); axis(axMO, 'square');

        axRho = nexttile(tl, 2 + s); hold(axRho, 'on');
        scatter(axRho, p.Rho_Measured(mask), p.Rho_Predicted(mask), 18, ...
            scenarioColors(s, :), 'filled', 'MarkerFaceAlpha', 0.55);
        add_identity_line(axRho);
        xlabel(axRho, 'Measured density (g cm^{-3})');
        ylabel(axRho, 'Predicted density (g cm^{-3})');
        grid(axRho, 'on'); axis(axRho, 'square');
    end
    title(tl, 'Held-out measured versus predicted values', 'Color', 'black');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_predicted_vs_measured'));
end

function add_identity_line(ax)
    limits = [min([ax.XLim ax.YLim]), max([ax.XLim ax.YLim])];
    plot(ax, limits, limits, '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.0);
    xlim(ax, limits); ylim(ax, limits);
end

function make_baseline_comparison_figure(summary, figureDir)
    modelOrder = ["physics_guided", "ridge", "physics_only", "gradient_boosting"];
    modelOrder = modelOrder(ismember(modelOrder, unique(summary.Model)));
    scenarios = ["A_within", "A_to_B_transfer"];
    mo = nan(numel(modelOrder), numel(scenarios));
    rho = nan(numel(modelOrder), numel(scenarios));
    for i = 1:numel(modelOrder)
        for j = 1:numel(scenarios)
            mask = summary.Model == modelOrder(i) & summary.Scenario == scenarios(j);
            if any(mask)
                mo(i, j) = summary.RMSE_MO(mask) / 0.03;
                rho(i, j) = summary.RMSE_Rho(mask) / 0.01;
            end
        end
    end
    labels = replace(modelOrder, ["physics_guided", "physics_only", "gradient_boosting"], ...
        ["Physics-guided", "Physics-only", "Gradient boosting"]);
    labels(labels == "ridge") = "Ridge";
    fig = publication_figure([11.0 4.8]);
    tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax1 = nexttile(tl); bar(ax1, categorical(labels, labels), mo, 'grouped');
    yline(ax1, 1, '--k', 'Tolerance'); ylabel(ax1, 'RMSE / 0.03');
    title(ax1, 'Molar ratio'); grid(ax1, 'on');
    ax2 = nexttile(tl); bar(ax2, categorical(labels, labels), rho, 'grouped');
    yline(ax2, 1, '--k', 'Tolerance'); ylabel(ax2, 'RMSE / 0.01 g cm^{-3}');
    title(ax2, 'Density'); grid(ax2, 'on');
    legend(ax2, {'Regime A rolling tests', 'A to B transfer'}, ...
        'Location', 'northoutside', 'Orientation', 'horizontal', 'Box', 'off');
    title(tl, 'Held-out baseline comparison', 'Color', 'black');
    export_figure_pdf(fig, fullfile(figureDir, 'fig_baseline_comparison'));
end

function [dateAgg, rawD, validD, acid, ammonia, water, invalidShare] = ...
        aggregate_process_for_figure(process, rawConductivity, blockSize)
    nBlocks = floor(height(process) / blockSize);
    last = nBlocks * blockSize;
    idx = reshape(1:last, blockSize, nBlocks);
    dateAgg = process.Date(idx(ceil(blockSize / 2), :));
    rawD = block_mean(rawConductivity(idx));
    d = process.conductivity_filtered;
    a = process.Q_H3PO4;
    n = process.Q_NH3;
    w = process.Q_H2O;
    valid = process.is_valid_mode;
    d(~valid) = NaN; a(~valid) = NaN; n(~valid) = NaN; w(~valid) = NaN;
    validD = block_mean(d(idx));
    acid = block_mean(a(idx));
    ammonia = block_mean(n(idx));
    water = block_mean(w(idx));
    invalidShare = mean(reshape(double(~valid(1:last)), blockSize, nBlocks), 1).';
    dateAgg = dateAgg(:);
end

function y = block_mean(x)
    y = mean(x, 1, 'omitnan').';
end

function colors = publication_colors()
    colors.blue = [0.00 0.45 0.70];
    colors.orange = [0.90 0.62 0.00];
    colors.red = [0.80 0.20 0.20];
    colors.dark = [0.15 0.15 0.15];
end

function fig = publication_figure(sizeInches)
    fig = figure('Visible', 'off', 'Color', 'white', 'Units', 'inches', ...
        'Position', [0.5 0.5 sizeInches]);
    set(fig, 'DefaultAxesFontName', 'Arial', 'DefaultAxesFontSize', 9, ...
        'DefaultAxesColor', 'white', 'DefaultAxesXColor', 'black', ...
        'DefaultAxesYColor', 'black', 'DefaultAxesGridColor', [0.82 0.82 0.82], ...
        'DefaultAxesMinorGridColor', [0.90 0.90 0.90], ...
        'DefaultTextFontName', 'Arial', 'DefaultTextFontSize', 9, ...
        'DefaultTextColor', 'black');
end

function export_figure_pdf(fig, stem)
    style_publication_figure(fig);
    exportgraphics(fig, [stem '.pdf'], 'ContentType', 'vector', ...
        'BackgroundColor', 'white');
    close(fig);
end

function require_private_input(filename, label, repoRoot)
    if isfile(filename)
        return;
    end

    relativePath = erase(filename, [repoRoot filesep]);
    contractPath = fullfile(repoRoot, 'docs', 'DATA_REQUIREMENTS.md');
    error('publication_validation_pipeline:MissingPrivateData', [ ...
        'Required private %s workbook is not available:\n  %s\n' ...
        'Raw industrial data are confidential and are not distributed with ' ...
        'this repository. Supply the file locally according to:\n  %s'], ...
        label, relativePath, contractPath);
end

function style_publication_figure(fig)
    fig.Color = 'white';
    fig.InvertHardcopy = 'off';
    axesHandles = findall(fig, 'Type', 'axes');
    for i = 1:numel(axesHandles)
        axesHandles(i).Color = 'white';
        axesHandles(i).XColor = 'black';
        axesHandles(i).YColor = 'black';
        axesHandles(i).GridColor = [0.82 0.82 0.82];
        axesHandles(i).GridAlpha = 0.65;
    end
    textHandles = findall(fig, 'Type', 'text');
    set(textHandles, 'Color', 'black');
    legendHandles = findall(fig, 'Type', 'legend');
    for i = 1:numel(legendHandles)
        legendHandles(i).Color = 'white';
        legendHandles(i).TextColor = 'black';
    end
end

function write_validation_markdown(filename, splits, selectedConfigurations, ...
        modelConfigurations, perSplit, summary, datasetCounts, journal, process, ...
        filterReport, cfg)
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    assert(fid >= 0, 'Could not open %s for writing.', filename);
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, '# Publication validation\n\n');
    fprintf(fid, 'Generated by `run_publication_validation.m` from the canonical workbooks in `data/publication/`. ');
    fprintf(fid, 'No random shuffling is used. The random seed for the optional boosting baseline is `%d`.\n\n', ...
        cfg.publication.random_seed);

    fprintf(fid, '## 1. Exact data splits\n\n');
    fprintf(fid, 'All intervals are left-closed and right-open: `start <= time < end`. ');
    fprintf(fid, 'Within-regime rolling origins advance by seven days.\n\n');
    fprintf(fid, '| Scenario | Split | Train interval | Test interval | Eligible | Note |\n');
    fprintf(fid, '|---|---:|---|---|---:|---|\n');
    for i = 1:height(splits)
        fprintf(fid, '| %s | %s | %s to %s | %s to %s | %s | %s |\n', ...
            splits.Scenario(i), splits.SplitID(i), md_date(splits.TrainStart(i)), ...
            md_date(splits.TrainEnd(i)), md_date(splits.TestStart(i)), ...
            md_date(splits.TestEnd(i)), string(splits.Eligible(i)), ...
            escape_md(splits.Note(i)));
    end
    fprintf(fid, '\nRegime B does not contain 21 days of paired laboratory coverage. The first B laboratory pair is after 21 May, ');
    fprintf(fid, 'and the last paired observation is %s. Therefore no complete `14-day train + 7-day test` within-B split exists; ', ...
        md_datetime(max(journal.Date)));
    fprintf(fid, 'no shortened or randomly sampled substitute was used.\n\n');

    fprintf(fid, '## 2. Model configurations\n\n');
    fprintf(fid, 'Lag, averaging window, and physics-guided nonlinearity were selected only once per scenario using an inner chronological split of the scenario training data (first nine days for fitting, remaining five days for validation), then frozen for every outer split in that scenario. The selection score is `RMSE_MO / 0.03 + RMSE_density / 0.01`. All fitted coefficients are re-estimated from each outer training interval only.\n\n');
    fprintf(fid, '| Scenario | Lag (min) | Window (min) | Mapping | Inner train | Inner validation | Score |\n');
    fprintf(fid, '|---|---:|---:|---|---|---|---:|\n');
    for i = 1:height(selectedConfigurations)
        fprintf(fid, '| %s | %d | %d | %s | %s to %s | %s to %s | %.4f |\n', ...
            selectedConfigurations.Scenario(i), selectedConfigurations.LagMin(i), ...
            selectedConfigurations.WindowMin(i), selectedConfigurations.ModelType(i), ...
            md_date(selectedConfigurations.InnerTrainStart(i)), ...
            md_date(selectedConfigurations.InnerTrainEnd(i)), ...
            md_date(selectedConfigurations.InnerValidationStart(i)), ...
            md_date(selectedConfigurations.InnerValidationEnd(i)), ...
            selectedConfigurations.SelectionScore(i));
    end
    fprintf(fid, '\n| Model | Inputs | Configuration |\n');
    fprintf(fid, '|---|---|---|\n');
    for i = 1:height(modelConfigurations)
        fprintf(fid, '| %s | %s | %s |\n', modelConfigurations.Model(i), ...
            modelConfigurations.Inputs(i), modelConfigurations.Configuration(i));
    end
    fprintf(fid, '\nThe physics-guided implementation and preprocessing functions in `src/` follow the R&D code, except that the requested wash-mode rule invalidates conductivity above %.0f (the previous upper limit was 50). Molar-ratio predictions are rounded to two decimals before validation, matching the production reporting setting.\n\n', ...
        cfg.conductivity_valid_max);
    fprintf(fid, 'At prediction time, the conductivity input to each fitted latent-property mapping is limited to that model''s training-data range. This prevents unconstrained polynomial or PCHIP extrapolation without changing preprocessing, temporal splits, or test targets.\n\n');

    fprintf(fid, '## 3. Final metrics\n\n');
    fprintf(fid, 'Residuals and bias use `prediction - measurement`. Fractions are reported on the 0-1 scale.\n\n');
    fprintf(fid, '### Per held-out split\n\n');
    fprintf(fid, '| Scenario | Split | Model | N train | N test | RMSE MO | MAE MO | Bias MO | P95 MO | Within 0.03 | RMSE density | MAE density | Bias density | P95 density | Within 0.01 |\n');
    fprintf(fid, '|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(perSplit)
        fprintf(fid, '| %s | %s | %s | %d | %d | %.4f | %.4f | %+.4f | %.4f | %.3f | %.4f | %.4f | %+.4f | %.4f | %.3f |\n', ...
            perSplit.Scenario(i), perSplit.SplitID(i), perSplit.Model(i), ...
            perSplit.NTrain(i), perSplit.NTest(i), perSplit.RMSE_MO(i), ...
            perSplit.MAE_MO(i), perSplit.Bias_MO(i), perSplit.P95AbsError_MO(i), ...
            perSplit.FractionWithin_MO_0p03(i), perSplit.RMSE_Rho(i), ...
            perSplit.MAE_Rho(i), perSplit.Bias_Rho(i), ...
            perSplit.P95AbsError_Rho(i), perSplit.FractionWithin_Rho_0p01(i));
    end

    fprintf(fid, '\n### Pooled held-out predictions by scenario\n\n');
    fprintf(fid, '| Scenario | Model | Splits | N train range | N test | RMSE MO | MAE MO | Bias MO | P95 MO | Within 0.03 | RMSE density | MAE density | Bias density | P95 density | Within 0.01 |\n');
    fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
    for i = 1:height(summary)
        fprintf(fid, '| %s | %s | %d | %d-%d | %d | %.4f | %.4f | %+.4f | %.4f | %.3f | %.4f | %.4f | %+.4f | %.4f | %.3f |\n', ...
            summary.Scenario(i), summary.Model(i), summary.NSplits(i), ...
            summary.NTrainMin(i), summary.NTrainMax(i), summary.NTest(i), ...
            summary.RMSE_MO(i), summary.MAE_MO(i), summary.Bias_MO(i), ...
            summary.P95AbsError_MO(i), summary.FractionWithin_MO_0p03(i), ...
            summary.RMSE_Rho(i), summary.MAE_Rho(i), summary.Bias_Rho(i), ...
            summary.P95AbsError_Rho(i), summary.FractionWithin_Rho_0p01(i));
    end

    fprintf(fid, '\n## 4. Reconciliation of 637, 119, and 767\n\n');
    countMap = containers.Map(cellstr(datasetCounts.Item), num2cell(datasetCounts.Count));
    fprintf(fid, 'The canonical source contains **%d** paired laboratory observations before process alignment. ', ...
        countMap('laboratory_pairs_nonmissing'));
    fprintf(fid, 'Before the requested conductivity-above-%.0f wash-mode exclusion, the canonical rerun with the previous upper limit of 50 reproduced **637** regime-A records (`lag=180 min, window=60 min`), **119** regime-B records (`lag=20 min, window=20 min`), and **767** combined records (`lag=50 min, window=60 min`). The combined mask partitioned as 643 regime A + 124 regime B = 767. Thus the original 11-record difference, `767 - (637 + 119)`, was caused by configuration-dependent acceptance masks.\n\n', ...
        cfg.conductivity_valid_max);
    fprintf(fid, 'With the current wash-mode exclusion, the independently regenerated counts are **%d** for regime A, **%d** for regime B, and **%d** for the combined mask; the current combined partition is **%d regime A + %d regime B = %d**. These values are reported as observed and are not forced to match the R&D report.\n\n', ...
        countMap('report_A_valid_lag180_window60'), ...
        countMap('report_B_valid_lag20_window20'), ...
        countMap('combined_valid_lag50_window60'), ...
        countMap('combined_mask_regime_A'), countMap('combined_mask_regime_B'), ...
        countMap('combined_valid_lag50_window60'));

    fprintf(fid, 'Independent process counts reproduce **%d imported minute records** and **%d jointly valid minute records**.\n\n', ...
        height(process), sum(process.is_valid_mode));

    fprintf(fid, '## 5. Limitations and leakage risks\n\n');
    fprintf(fid, '- No full within-regime-B split exists under the prespecified 14+7-day protocol. B evidence is limited to the A-to-B transfer test.\n');
    fprintf(fid, '- Hyperparameter selection is nested chronologically and uses no outer-test targets. The same selected lag/window defines the laboratory rows used by every baseline in a split.\n');
    fprintf(fid, '- The authoritative conductivity filter and flow despiking are applied once to the full process series. They do not use laboratory targets, but centered robust windows, Savitzky-Golay smoothing, and PCHIP repair can use nearby future process values. This creates a short operational look-ahead risk even though it does not mix train and test target values.\n');
    fprintf(fid, '- Laboratory alignment uses a centered averaging window around `lab time - lag`. Candidates with `lag < window/2` can include process observations after the laboratory timestamp. This is retained from the engineering implementation and should be constrained in a prospective deployment study.\n');
    fprintf(fid, '- Rolling regime-A tests have non-overlapping seven-day test intervals but overlapping 14-day training intervals; pooled metrics therefore summarize test observations, not independent model fits.\n');
    fprintf(fid, '- The physics-only baseline fixes P2O5 at the process target and evaluates the unfitted acid-density prior. It is a reference calculation, not a separately calibrated mechanistic model.\n');
    fprintf(fid, '- The boosting baseline requires Statistics and Machine Learning Toolbox. It was %s in this run.\n', ...
        ternary(has_ensemble(), 'included', 'not available and therefore skipped'));
    fprintf(fid, '- Conductivity filtering corrected %d values, including %d raw missing values; these corrections are part of the authoritative preprocessing rather than learned model parameters.\n', ...
        filterReport.corrected_count, filterReport.raw_missing_count);
    fprintf(fid, '- The wash-mode rule invalidated %d raw process minutes with conductivity above %.0f; these minutes are removed before smoothing and remain invalid during laboratory-window aggregation.\n', ...
        filterReport.upper_limit_count, cfg.conductivity_valid_max);
end

function value = md_date(dateValue)
    value = string(dateValue, 'yyyy-MM-dd HH:mm');
end

function value = md_datetime(dateValue)
    value = string(dateValue, 'yyyy-MM-dd HH:mm:ss');
end

function value = escape_md(value)
    value = replace(string(value), '|', '\|');
end

function value = ternary(condition, trueValue, falseValue)
    if condition
        value = trueValue;
    else
        value = falseValue;
    end
end
