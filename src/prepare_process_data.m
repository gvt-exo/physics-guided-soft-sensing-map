function process = prepare_process_data(Date_1min, acidFlow, ammoniaFlowFallback, ...
        ammoniaFlowPrimary, waterFlow, x_stream, cfg)
%PREPARE_PROCESS_DATA Build process table and invalidate clearly bad modes.

    Date_1min = Date_1min(:);
    acidFlow = acidFlow(:);
    ammoniaFlowFallback = ammoniaFlowFallback(:);
    ammoniaFlowPrimary = ammoniaFlowPrimary(:);
    waterFlow = waterFlow(:);
    x_stream = x_stream(:);

    Q_H3PO4_raw = acidFlow;
    Q_NH3_raw = ammoniaFlowPrimary;
    useFallback = ~(ammoniaFlowPrimary >= cfg.nh3_channel_switch_threshold_kg_h);
    Q_NH3_raw(useFallback) = ammoniaFlowFallback(useFallback);
    Q_H2O_raw = waterFlow;

    [Q_H3PO4, spikeQ_H3PO4] = filter_negative_spikes_segmented( ...
        Date_1min, ...
        Q_H3PO4_raw, cfg.flow_despike_window, cfg.flow_despike_kMad, ...
        cfg.flow_despike_maxRunLen, cfg.flow_despike_expandN, ...
        cfg.temporal_gap_reset_minutes);
    [Q_NH3, spikeQ_NH3] = filter_negative_spikes_segmented( ...
        Date_1min, ...
        Q_NH3_raw, cfg.flow_despike_window, cfg.flow_despike_kMad, ...
        cfg.flow_despike_maxRunLen, cfg.flow_despike_expandN, ...
        cfg.temporal_gap_reset_minutes);
    [Q_H2O, spikeQ_H2O] = filter_negative_spikes_segmented( ...
        Date_1min, ...
        Q_H2O_raw, cfg.flow_despike_window, cfg.flow_despike_kMad, ...
        cfg.flow_despike_maxRunLen, cfg.flow_despike_expandN, ...
        cfg.temporal_gap_reset_minutes);

    conductivity_filtered_raw = x_stream;
    badConductivity = ~isfinite(conductivity_filtered_raw) | ...
        conductivity_filtered_raw < cfg.conductivity_valid_min | ...
        conductivity_filtered_raw > cfg.conductivity_valid_max;
    conductivity_filtered = conductivity_filtered_raw;
    conductivity_filtered(badConductivity) = NaN;

    missingFlows = ~isfinite(Q_H3PO4) | ~isfinite(Q_NH3) | ~isfinite(Q_H2O);
    negativeFlows = Q_H3PO4 < 0 | Q_NH3 < 0 | Q_H2O < 0;
    lowAcidWithAmmonia = Q_H3PO4 <= cfg.min_h3po4_flow_m3_h & Q_NH3 >= cfg.min_nh3_flow_kg_h;
    highAcid = Q_H3PO4 > cfg.max_h3po4_flow_m3_h;
    lowAmmonia = Q_NH3 < cfg.min_nh3_flow_kg_h;
    lowH2O = Q_H2O <= cfg.min_h2o_flow_m3_h;
    highH2O = Q_H2O > cfg.max_h2o_flow_m3_h;

    is_valid_mode = ~(missingFlows | negativeFlows | badConductivity | ...
        lowAcidWithAmmonia | highAcid | lowAmmonia | lowH2O | highH2O);

    process = table();
    process.Date = Date_1min;
    process.Q_H3PO4_raw = Q_H3PO4_raw;
    process.Q_NH3_raw = Q_NH3_raw;
    process.Q_H2O_raw = Q_H2O_raw;
    process.Q_H3PO4 = Q_H3PO4;
    process.Q_NH3 = Q_NH3;
    process.Q_H2O = Q_H2O;
    process.conductivity_filtered_raw = conductivity_filtered_raw;
    process.conductivity_filtered = conductivity_filtered;
    process.is_valid_mode = is_valid_mode;
    process.invalid_missing_flows = missingFlows;
    process.invalid_negative_flows = negativeFlows;
    process.invalid_bad_conductivity = badConductivity;
    process.invalid_low_acid = lowAcidWithAmmonia;
    process.invalid_high_acid = highAcid;
    process.invalid_low_ammonia = lowAmmonia;
    process.invalid_low_h2o = lowH2O;
    process.invalid_high_h2o = highH2O;
    process.invalid_q_h3po4_spike = spikeQ_H3PO4;
    process.invalid_q_nh3_spike = spikeQ_NH3;
    process.invalid_q_h2o_spike = spikeQ_H2O;
    process.invalid_flow_spike = spikeQ_H3PO4 | spikeQ_NH3 | spikeQ_H2O;
end

function [xClean, spikeMask] = filter_negative_spikes_segmented( ...
        dates, x, win, kMad, maxRunLen, expandN, gapThresholdMinutes)
    n = numel(x);
    xClean = nan(n, 1);
    spikeMask = false(n, 1);
    if n == 0
        return;
    end
    if isdatetime(dates)
        deltaMinutes = minutes(diff(dates));
        breaks = ~isfinite(deltaMinutes) | deltaMinutes < 0 | ...
            deltaMinutes > gapThresholdMinutes;
    else
        delta = diff(double(dates));
        breaks = ~isfinite(delta) | delta < 0 | delta > gapThresholdMinutes;
    end
    starts = [1; find(breaks) + 1];
    ends = [starts(2:end) - 1; n];
    for segmentIndex = 1:numel(starts)
        idx = (starts(segmentIndex):ends(segmentIndex))';
        [xClean(idx), spikeMask(idx)] = filter_negative_spikes_only( ...
            x(idx), win, kMad, maxRunLen, expandN);
    end
end

function [x_clean, spikeMask] = filter_negative_spikes_only(x, win, kMad, maxRunLen, expandN)
%FILTER_NEGATIVE_SPIKES_ONLY Removes short downward spikes without smoothing normal signal.

    x = x(:);
    x_clean = x;

    if ~any(isfinite(x))
        spikeMask = false(size(x));
        return;
    end

    x_med = movmedian(x, win, 'omitnan');
    x_mad = movmad(x, win, 1, 'omitnan');
    x_mad(x_mad < eps) = eps;
    rawSpike = x < (x_med - kMad * 1.4826 .* x_mad);

    spikeMask = false(size(x));
    d = diff([false; rawSpike; false]);
    runStart = find(d == 1);
    runEnd = find(d == -1) - 1;

    for i = 1:numel(runStart)
        runLen = runEnd(i) - runStart(i) + 1;
        if runLen <= maxRunLen
            spikeMask(runStart(i):runEnd(i)) = true;
        end
    end

    if expandN > 0
        spikeMask = conv(double(spikeMask), ones(2 * expandN + 1, 1), 'same') > 0;
    end

    x_tmp = x;
    x_tmp(spikeMask) = NaN;

    if sum(~isnan(x_tmp)) >= 2
        x_clean = fillmissing(x_tmp, 'pchip');
        x_clean = fillmissing(x_clean, 'nearest');
    end
end
