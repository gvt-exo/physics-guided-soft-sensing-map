function exportData = load_export_data(filename, sheetName)
%LOAD_EXPORT_DATA Reads process export file and maps columns into fields.
%   exportData = LOAD_EXPORT_DATA(filename, sheetName) reads the specified file.

    if nargin < 1 || isempty(filename)
        error('load_export_data:MissingFilename', [ ...
            'A private process-data workbook path is required. ' ...
            'See docs/DATA_REQUIREMENTS.md for the anonymized input contract.']);
    end

    if nargin < 2 || isempty(sheetName)
        sheetName = 1;
    end

    opts = detectImportOptions(filename, 'Sheet', sheetName, ...
        'VariableNamingRule', 'preserve');
    T = readtable(filename, opts);

    if width(T) < 6
        error('load_export_data:InvalidSchema', [ ...
            'The process workbook must contain at least six columns: ' ...
            'timestamp, water flow, conductivity, ammonia flow fallback, ' ...
            'acid flow, and ammonia flow primary. See docs/DATA_REQUIREMENTS.md.']);
    end

    rawDate = T{:, 1};
    Date = parse_date_column(rawDate);

    exportData = struct();
    exportData.Date = Date;
    exportData.Date_1min = Date;

    varNames = T.Properties.VariableNames;
    for k = 2:numel(varNames)
        fieldName = matlab.lang.makeValidName(varNames{k});
        exportData.(fieldName) = coerce_numeric_column(T{:, k});
    end

    % Public-code aliases follow the canonical workbook column order and do
    % not expose plant historian identifiers.
    genericNames = {'WaterFlow', 'Conductivity', 'AmmoniaFlowFallback', ...
        'AcidFlow', 'AmmoniaFlowPrimary', 'AcidFlowDuplicate'};
    for k = 1:min(numel(genericNames), width(T) - 1)
        exportData.(genericNames{k}) = coerce_numeric_column(T{:, k + 1});
    end

    % Historian workbooks may contain complete timestamp coverage but store
    % late-evening blocks after the following midnight row. Stateful filters
    % require chronological order, so sort every imported channel together.
    originalDate = exportData.Date_1min;
    if isdatetime(originalDate)
        originalDeltaMinutes = minutes(diff(originalDate));
    else
        originalDeltaMinutes = diff(double(originalDate));
    end
    importDiagnostics = struct();
    importDiagnostics.backward_time_transitions = sum(originalDeltaMinutes < 0);
    importDiagnostics.duplicate_timestamps = numel(originalDate) - ...
        numel(unique(originalDate));
    importDiagnostics.rows_reordered = sum((1:numel(originalDate))' ~= ...
        sort_order(originalDate));

    [sortedDate, order] = sort(exportData.Date_1min);
    exportData.Date = sortedDate;
    exportData.Date_1min = sortedDate;
    fields = fieldnames(exportData);
    for k = 1:numel(fields)
        fieldName = fields{k};
        if strcmp(fieldName, 'Date') || strcmp(fieldName, 'Date_1min')
            continue;
        end
        values = exportData.(fieldName);
        if numel(values) == numel(order)
            exportData.(fieldName) = values(order);
        end
    end
    exportData.ImportDiagnostics = importDiagnostics;
end

function order = sort_order(values)
    [~, order] = sort(values);
end

function values = coerce_numeric_column(rawValues)
%COERCE_NUMERIC_COLUMN Converts mixed Excel numeric/blank columns to double.

    if isnumeric(rawValues) || islogical(rawValues)
        values = double(rawValues);
        return;
    end

    if iscell(rawValues)
        values = nan(size(rawValues));
        for i = 1:numel(rawValues)
            value = rawValues{i};
            if isempty(value)
                continue;
            elseif isnumeric(value) || islogical(value)
                if isscalar(value)
                    values(i) = double(value);
                end
            else
                parsed = str2double(strrep(strtrim(string(value)), ',', '.'));
                if isfinite(parsed)
                    values(i) = parsed;
                end
            end
        end
        return;
    end

    values = str2double(strrep(strtrim(string(rawValues)), ',', '.'));
    values = double(values);
end

function Date = parse_date_column(rawDate)
    rawDate = rawDate(:);

    if isa(rawDate, 'datetime')
        Date = rawDate;
        return;
    end

    if isnumeric(rawDate)
        Date = datetime(rawDate, 'ConvertFrom', 'excel');
        return;
    end

    if isstring(rawDate) || ischar(rawDate)
        Date = parse_date_strings(string(rawDate));
        return;
    end

    if iscell(rawDate)
        Date = NaT(size(rawDate));
        for k = 1:numel(rawDate)
            value = rawDate{k};

            if isempty(value)
                continue;
            end

            if isa(value, 'datetime')
                Date(k) = value;
            elseif isnumeric(value)
                if ~isnan(value)
                    Date(k) = datetime(value, 'ConvertFrom', 'excel');
                end
            else
                textValue = strtrim(string(value));
                if textValue == ""
                    continue;
                end
                Date(k) = parse_date_strings(textValue);
            end
        end
        return;
    end

    error('load_export_data:InvalidTimestamp', ...
        'The process timestamp column could not be parsed.');
end

function Date = parse_date_strings(textValues)
    textValues = string(textValues);
    Date = NaT(size(textValues));

    formats = ["dd.MM.yyyy HH:mm:ss", "dd.MM.yyyy HH:mm"];
    for f = 1:numel(formats)
        mask = ismissing(Date) & strlength(strtrim(textValues)) > 0;
        if ~any(mask)
            break;
        end

        try
            Date(mask) = datetime(textValues(mask), 'InputFormat', formats(f));
        catch
        end
    end

    mask = ismissing(Date) & strlength(strtrim(textValues)) > 0;
    if any(mask)
        Date(mask) = datetime(textValues(mask));
    end
end
