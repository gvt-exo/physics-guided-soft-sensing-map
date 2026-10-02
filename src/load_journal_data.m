function journal = load_journal_data(filename, sheetName)
%LOAD_JOURNAL_DATA Reads lab journal and removes empty values.
%   journal = LOAD_JOURNAL_DATA(filename, sheetName) reads the specified file.

    if nargin < 1 || isempty(filename)
        error('load_journal_data:MissingFilename', [ ...
            'A private laboratory-data workbook path is required. ' ...
            'See docs/DATA_REQUIREMENTS.md for the anonymized input contract.']);
    end

    if nargin < 2 || isempty(sheetName)
        sheetName = 1;
    end

    opts = detectImportOptions(filename, 'Sheet', sheetName, ...
        'VariableNamingRule', 'preserve');
    opts.DataRange = 'A:C';

    T = readtable(filename, opts);

    if width(T) < 3
        error('load_journal_data:InvalidSchema', [ ...
            'The laboratory workbook must contain timestamp, laboratory ' ...
            'molar ratio, and laboratory density as its first three columns. ' ...
            'See docs/DATA_REQUIREMENTS.md.']);
    end

    rawDate = T{:, 1};
    Date_all = parse_date_column(rawDate);

    MO_all = T{:, 2};
    Rho_all = T{:, 3};

    mask_values = ~isnan(MO_all) & ~isnan(Rho_all);

    journal = struct();
    journal.Date_all = Date_all;
    journal.MO_all = MO_all;
    journal.Rho_all = Rho_all;

    journal.Date = Date_all(mask_values);
    journal.MO = MO_all(mask_values);
    journal.Rho = Rho_all(mask_values);

    journal.values_array = [datenum(journal.Date), journal.MO, journal.Rho];
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

    error('load_journal_data:InvalidTimestamp', ...
        'The laboratory timestamp column could not be parsed.');
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
