# Reproducibility specification

This document records the settings frozen in the publication code. It is descriptive only; the executable definitions remain in `src/config_soft_sensor.m` and `scripts/publication/publication_validation_pipeline.m`.

## Deterministic settings

| Setting | March--June benchmark | Extended validation |
|---|---:|---:|
| Random seed | `20260928` | `20261001` |
| Outer training duration | 14 days | 14 days for adapted rolling models; full eligible pre-maintenance domain for frozen models |
| Outer test duration | 7 days | 7 days for rolling models; full post-maintenance interval for strict external transfer |
| Rolling step | 7 days | 7 days |
| Inner chronological fit / validation | 9 / 5 days | 9 / 5 days |
| Minimum aligned training / test pairs | 40 / 10 | 40 / 10 |

No observation shuffling is used. Candidate lag, averaging window, mapping type, and fitted parameters are selected from training data only.

The search spaces are explicit:

- lag: `0:10:180` minutes;
- averaging window: `10`, `20`, `30`, or `60` minutes;
- physics-guided mapping: linear, quadratic, or PCHIP spline;
- Ridge penalty: `0`, `1e-4`, `1e-3`, `1e-2`, `1e-1`, `1`, `10`, or `100`;
- LSBoost: 100 cycles, learning rate 0.05, minimum leaf size 10, maximum 20 splits.

## Frozen preprocessing and domain rules

The publication configuration uses a valid conductivity range of 5--30, acid flow of 6--12 m3/h, minimum ammonia flow of 1250 kg/h, and minimum water flow of 10 m3/h. Temporal filter state resets whenever the timestamp gap exceeds five minutes, which prevents state transfer across the maintenance outage from `2026-06-06` to `2026-07-07`.

At inference, the conductivity input to a fitted latent-property mapping is clamped to the conductivity support observed in that model's training data. This training-domain guard is enabled by `cfg.clamp_mapping_input_to_training_range = true` and does not use test targets.

## Validation domains

- Regime boundary for the March--June study: `2026-05-21 00:00:00`.
- Strict external model training: eligible observations from `2026-03-01 00:00:00` through, but not including, `2026-06-06 00:00:00`.
- Strict external test: `2026-07-07 00:00:00` through, but not including, `2026-09-29 00:00:00`.
- Post-maintenance rolling eligibility: at least 40 aligned training pairs and 10 common test pairs after preprocessing and alignment. In the current canonical results, all ten candidate windows P01--P10 satisfy this rule.

The strict external model uses no post-maintenance targets for fitting or hyperparameter selection. The adapted physics-guided configuration is selected once on the first post-maintenance training window and then frozen; coefficients are refitted within each later training window.

## Public-output checks

Run the data-free audit from the repository root:

```text
python tests/test_public_release.py
```

It verifies that no raw workbook or MAT file is tracked, the manuscript/arXiv figure packages match, all ten extended rolling windows satisfy the published minimum-sample rule, the committed dataset counts are 260,642 process rows and 1,325 complete laboratory pairs, and the pooled/per-split CSV metrics agree with the committed held-out predictions. It also cross-checks the rounded pooled tables in `VALIDATION.md` and `VALIDATION_EXTENDED.md` against their corresponding CSV files.

## Known limitations

The preprocessing is retrospective: centered robust windows, Savitzky--Golay smoothing, reconstruction, and centered laboratory aggregation can use nearby future process values. They do not use held-out laboratory targets, but a prospective online implementation should replace them with causal alternatives. Overlapping rolling training windows also mean pooled errors are descriptive rather than independent-fold confidence estimates.
