function [x_stream, filter_report] = filter_conductivity_stream(conductivityRaw, Date_1min, cfg)
%FILTER_CONDUCTIVITY_STREAM Streaming conductivity filtering without leakage.

    conductivityRaw = conductivityRaw(:);
    if nargin < 2 || isempty(Date_1min)
        Date_1min = (1:numel(conductivityRaw))';
    else
        Date_1min = Date_1min(:);
    end

    N = numel(conductivityRaw);
    x_stream = nan(N, 1);
    upperLimitMask = isfinite(conductivityRaw) & ...
        conductivityRaw > cfg.conductivity_valid_max;
    conductivityForFiltering = conductivityRaw;
    conductivityForFiltering(upperLimitMask) = NaN;

    filter_report = struct();
    filter_report.Date = Date_1min;
    filter_report.raw_missing_mask = ~isfinite(conductivityRaw);
    filter_report.upper_limit_mask = upperLimitMask;
    filter_report.outlier_mask = false(N, 1);
    filter_report.corrected_mask = false(N, 1);
    filter_report.segment_id = zeros(N, 1);

    if N == 0
        filter_report.raw_missing_count = 0;
        filter_report.upper_limit_count = 0;
        filter_report.outlier_count = 0;
        filter_report.corrected_count = 0;
        filter_report.context = 0;
        return;
    end

    segmentStart = temporal_segment_starts(Date_1min, cfg.temporal_gap_reset_minutes);
    segmentEnd = [segmentStart(2:end) - 1; N];
    context = 0;
    for segmentIndex = 1:numel(segmentStart)
        idx = (segmentStart(segmentIndex):segmentEnd(segmentIndex))';
        [xSegment, badSegment, fillSegment, segmentMeta] = ...
            filter_contiguous_segment(conductivityForFiltering(idx), cfg);
        x_stream(idx) = xSegment;
        filter_report.outlier_mask(idx) = badSegment;
        filter_report.corrected_mask(idx) = fillSegment;
        filter_report.segment_id(idx) = segmentIndex;
        context = max(context, segmentMeta.context);
    end

    x_stream(upperLimitMask) = NaN;
    filter_report.raw_missing_count = sum(filter_report.raw_missing_mask);
    filter_report.upper_limit_count = sum(filter_report.upper_limit_mask);
    filter_report.outlier_count = sum(filter_report.outlier_mask);
    filter_report.corrected_count = sum(filter_report.corrected_mask);
    filter_report.context = context;
    filter_report.step_size = cfg.filter.stepSize;
    filter_report.init_history = cfg.filter.initHistory;
    filter_report.segment_count = numel(segmentStart);
    filter_report.segment_start_indices = segmentStart;
end

function starts = temporal_segment_starts(dateValues, gapThresholdMinutes)
    n = numel(dateValues);
    if n == 0
        starts = zeros(0, 1);
        return;
    end
    if isdatetime(dateValues)
        deltaMinutes = minutes(diff(dateValues));
        breaks = ~isfinite(deltaMinutes) | deltaMinutes < 0 | ...
            deltaMinutes > gapThresholdMinutes;
    else
        delta = diff(double(dateValues));
        breaks = ~isfinite(delta) | delta < 0 | delta > gapThresholdMinutes;
    end
    starts = [1; find(breaks) + 1];
end

function [xStream, badMask, fillMask, meta] = filter_contiguous_segment(x, cfg)
    x = x(:);
    n = numel(x);
    xStream = nan(n, 1);
    badMask = false(n, 1);
    fillMask = false(n, 1);

    win = cfg.filter.win;
    expandN = cfg.filter.expandN;
    sgolayFrame = cfg.filter.sgolayFrame;
    context = max((win - 1) / 2 + expandN, (sgolayFrame - 1) / 2);
    context = max(0, ceil(context));
    meta = struct('context', context);

    if n <= 1
        [xStream, badMask, fillMask] = process_signal_chunk(x, cfg);
        return;
    end

    initHistory = min(cfg.filter.initHistory, max(n - 1, 1));
    stepSize = cfg.filter.stepSize;
    bufferStart = 1;
    bufferRaw = x(1:initHistory);
    emittedUntil = 0;
    nextPos = initHistory + 1;

    while nextPos <= n
        blockEnd = min(nextPos + stepSize - 1, n);
        bufferRaw = [bufferRaw; x(nextPos:blockEnd)]; %#ok<AGROW>
        bufferEnd = blockEnd;

        [xBuffer, badBuffer, fillBuffer] = process_signal_chunk(bufferRaw, cfg);
        safeEnd = bufferEnd - context;

        if safeEnd > emittedUntil
            globalIdx = (emittedUntil + 1:safeEnd)';
            localIdx = globalIdx - bufferStart + 1;
            xStream(globalIdx) = xBuffer(localIdx);
            badMask(globalIdx) = badBuffer(localIdx);
            fillMask(globalIdx) = fillBuffer(localIdx);
            emittedUntil = safeEnd;
        end

        keepStart = max(bufferStart, emittedUntil - context + 1);
        localKeepStart = keepStart - bufferStart + 1;
        bufferRaw = bufferRaw(localKeepStart:end);
        bufferStart = keepStart;
        nextPos = blockEnd + 1;
    end

    [xBuffer, badBuffer, fillBuffer] = process_signal_chunk(bufferRaw, cfg);
    if emittedUntil < n
        globalIdx = (emittedUntil + 1:n)';
        localIdx = globalIdx - bufferStart + 1;
        xStream(globalIdx) = xBuffer(localIdx);
        badMask(globalIdx) = badBuffer(localIdx);
        fillMask(globalIdx) = fillBuffer(localIdx);
    end
end

function [x_smooth, badMask, fillMask] = process_signal_chunk(x, cfg)
    x = x(:);
    rawMissingMask = ~isfinite(x);
    x(rawMissingMask) = NaN;

    x_med = movmedian(x, cfg.filter.win, 'omitnan');
    x_mad = movmad(x, cfg.filter.win, 1, 'omitnan');
    x_mad(x_mad < eps) = eps;

    badMask = x < (x_med - cfg.filter.thr * 1.4826 .* x_mad);
    if cfg.filter.expandN > 0
        badMask = conv(double(badMask), ones(2 * cfg.filter.expandN + 1, 1), 'same') > 0;
    end

    x_clean = x;
    x_clean(badMask | rawMissingMask) = NaN;

    nValid = sum(~isnan(x_clean));
    if nValid >= 2
        x_clean = fillmissing(x_clean, 'pchip');
        x_clean = fillmissing(x_clean, 'nearest');
    elseif nValid == 1
        x_clean(isnan(x_clean)) = x_clean(find(~isnan(x_clean), 1, 'first'));
    else
        x_clean = zeros(size(x_clean));
    end

    x_clean = min(max(x_clean, cfg.filter.lower_clip), cfg.filter.upper_clip);
    fillMask = badMask | rawMissingMask;

    if numel(x_clean) >= cfg.filter.sgolayFrame
        x_smooth = sgolayfilt(x_clean, cfg.filter.sgolayOrder, cfg.filter.sgolayFrame);
    else
        x_smooth = x_clean;
    end
end
