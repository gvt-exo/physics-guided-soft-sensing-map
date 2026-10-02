# Private input data contract

The publication workflows require confidential process and laboratory data that are not part of this repository. Store them only in the ignored local directory `data/publication/`. Never commit the workbooks or transformed row-level source data.

Only anonymized variable names are used below. Source-system identifiers should remain outside the repository.

## Required files

| Workflow | Process workbook | Laboratory workbook |
|---|---|---|
| March--June benchmark | `process_2026-03-01_2026-06-06.xlsx` | `laboratory_2026-03-01_2026-06-06.xlsx` |
| Extended validation | `process_2026-03-01_2026-09-29.xlsx` | `laboratory_2026-03-01_2026-10-01.xlsx` |

The first worksheet is read by default. The extended process file must preserve the maintenance gap from `2026-06-06 00:00:00` to `2026-07-07 00:00:00`; temporal filters reset across gaps longer than five minutes.

## Process workbook

The process workbook is expected to contain nominally one-minute observations. Gaps are allowed and timestamps need not arrive sorted; all channels are sorted together before stateful filtering. The loader uses the following column order:

| Column | Anonymized variable | Expected type / unit |
|---:|---|---|
| 1 | timestamp | Excel datetime or text datetime |
| 2 | water flow | numeric, m3/h |
| 3 | conductivity | numeric, process conductivity unit |
| 4 | ammonia flow, fallback measurement | numeric, kg/h |
| 5 | acid flow | numeric, m3/h |
| 6 | ammonia flow, primary measurement | numeric, kg/h |
| 7 (optional) | acid flow, duplicate measurement | numeric, m3/h; imported only for diagnostics and not used by the publication model |

The two ammonia-flow columns are anonymized redundant measurements of the same process variable. Their selection rule is defined in `src/prepare_process_data.m`. Missing numeric values may be blank or `NaN`.

## Laboratory workbook

The laboratory workbook must contain these first three columns:

| Column | Anonymized variable | Expected type / unit |
|---:|---|---|
| 1 | timestamp | Excel datetime or text datetime |
| 2 | laboratory molar ratio | numeric, dimensionless |
| 3 | laboratory density | numeric, g/cm3 |

Rows lacking either laboratory target are retained in import counts but excluded from complete-pair modeling. Laboratory timestamps may be irregular and sparse.

## Timestamp conventions

- Timestamps are interpreted as local, timezone-naive process time.
- Accepted text forms include `dd.MM.yyyy HH:mm:ss` and `dd.MM.yyyy HH:mm`; MATLAB-compatible datetime text is used as a fallback.
- Validation intervals are left-closed and right-open.
- Do not interpolate laboratory targets or fill the maintenance gap.

## Privacy boundary

Before placing a local file under `data/publication/`, remove workbook metadata and worksheets that are not needed by this contract. Do not place company or site names, equipment identifiers, source-system tags, usernames, customer/project identifiers, or credentials in filenames, headers, comments, or configuration files. The public validation code relies only on the anonymized aliases above.
